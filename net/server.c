#define TINYCSOCKET_IMPLEMENTATION
#include "interop.h"
#include "tinycsocket.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_CONNECTIONS 1024
#define RECV_BUFSIZE 1024

typedef struct UserData {
  unsigned long long id;
  size_t pidx;
  size_t start;
  size_t end;
  char buf[RECV_BUFSIZE];
} UserData;

typedef struct PlayerData {
  ClientMsgUpdate data;
  ServerMsgPlayerMeta meta;
  int is_valid;
  TcsSocket socket;
} PlayerData;

ServerMsgMeta meta = {.score = {0, 0}};
PlayerData pdata[MAX_CONNECTIONS] = {};

#ifdef DEBUG
#define LOG_DEBUG(...) printf(__VA_ARGS__)
#else
#define LOG_DEBUG(...) __VA_ARGS__;
#endif

static int show_error(const char *error_text) {
  fprintf(stderr, "%s", error_text);
  return -1;
}

void broadcast(const uint8_t *msg, size_t msg_size, unsigned long long ignore) {
  for (size_t i = 0; i < MAX_CONNECTIONS; ++i) {
    if (pdata[i].is_valid && pdata[i].meta.id != ignore) {
      tcs_send(pdata[i].socket, msg, msg_size, TCS_MSG_SENDALL, NULL);
      LOG_DEBUG("Sending broadcast to %llu\n", pdata[i].meta.id);
    }
  }
}

void broadcast_meta() {
  struct __attribute__((packed)) {
    ServerMsgTag tag;
    ServerMsgMeta data;
  } msg = {
      .tag = ServerMeta,
      .data = meta,
  };
  broadcast((const uint8_t *)&msg, sizeof(msg), UINT64_MAX);
}

void disconnect(struct TcsPoll *poll, TcsSocket socket, UserData *user_data) {
  tcs_poll_remove(poll, socket);
  tcs_close(&socket);
  struct __attribute__((packed)) {
    ServerMsgTag tag;
    ServerMsgDisconnected data;
  } msg = {.tag = ServerDisconnected,
           .data = {
               .id = user_data->id,
           }};
  pdata[user_data->pidx].is_valid = false;
  broadcast((const uint8_t *)&msg, sizeof(msg), UINT64_MAX);
  free(user_data);
}

void *has_full_message(UserData *user, size_t n, int *looping) {
  if (user->end < user->start + n + 4) {
    if (looping != NULL) {
      *looping = 0;
    }
    return NULL;
  }
  void *ret = user->buf + user->start + 4;
  user->start += n + 4;
  return ret;
}

int main(int argc, char *argv[]) {
  if (tcs_lib_init() != TCS_SUCCESS)
    return show_error("Could not init tinycsocket");

  TcsSocket listen_socket = TCS_SOCKET_INVALID;

  printf("Starting server on %s\n", argv[1]);
  if (tcs_socket_tcp_str(&listen_socket, argv[1], NULL, 0) != TCS_SUCCESS)
    return show_error("Could not create server socket");

  if (tcs_listen(listen_socket, TCS_BACKLOG_MAX) != TCS_SUCCESS)
    return show_error("Could not listen on socket");

  tcs_opt_nonblocking_set(listen_socket, true);
  tcs_opt_ip_no_delay_set(listen_socket, true);

  struct TcsPoll *poll = NULL;
  tcs_poll_create(&poll);

  unsigned long long client_id = 0;
  struct TcsPollEvent ev[MAX_CONNECTIONS] = {};
  while (69) {
    TcsSocket child_socket = TCS_SOCKET_INVALID;
    if (tcs_accept(listen_socket, &child_socket, NULL) == TCS_SUCCESS) {
      tcs_opt_ip_no_delay_set(child_socket, true);
      tcs_opt_nonblocking_set(child_socket, true);
      LOG_DEBUG("Accepted client: %lld\n", client_id);

      // broadcast to everybody else
      struct __attribute__((packed)) {
        ServerMsgTag tag;
        ServerMsgConnected data;
      } msg = {.tag = ServerConnected,
               .data = {
                   .id = client_id,
               }};

      broadcast((const uint8_t *)&msg, sizeof(msg), UINT64_MAX);

      UserData *data = (UserData *)calloc(1, sizeof(UserData));
      data->id = client_id;

      // find a slot for this player in 'pdata'
      size_t p;
      for (p = 0; p < MAX_CONNECTIONS; ++p) {
        if (!pdata[p].is_valid) {
          break;
        }
      }
      pdata[p].meta = (ServerMsgPlayerMeta){};
      pdata[p].meta.id = client_id;
      pdata[p].socket = child_socket;
      pdata[p].data = (ClientMsgUpdate){};
      pdata[p].is_valid = 1;
      data->pidx = p;

      // send existing client list to player
      for (size_t i = 0; i < MAX_CONNECTIONS; ++i) {
        if (!pdata[i].is_valid)
          continue;
        if (i == p)
          continue;
        {
          struct __attribute__((packed)) {
            ServerMsgTag tag;
            ServerMsgConnected data;
          } msg = {.tag = ServerConnected,
                   .data = {
                       .id = pdata[i].meta.id,
                   }};
          tcs_send(child_socket, (const uint8_t *)&msg, sizeof(msg),
                   TCS_MSG_SENDALL, NULL);
          broadcast_meta();
        }
        {
          struct __attribute__((packed)) {
            ServerMsgTag tag;
            ServerMsgPlayerMeta data;
          } msg = {
              .tag = ServerPlayerMeta,
              .data = pdata[i].meta,
          };
          tcs_send(child_socket, (const uint8_t *)&msg, sizeof(msg),
                   TCS_MSG_SENDALL, NULL);
        }
        LOG_DEBUG("Sending existing client id %llu to %llu\n", pdata[i].meta.id,
                  data->id);
      }

      // add to our poll list
      tcs_poll_add(poll, child_socket, data, TCS_POLL_READ);

      // do this last so we stay sane
      client_id++;
    }

    size_t events;
    TcsResult poll_res = tcs_poll_wait(poll, ev, MAX_CONNECTIONS, &events, 0);

    for (size_t i = 0; i < events; ++i) {
      if (ev[i].can_read) {
        size_t received_size = 0;
        UserData *user = ev[i].user_data;
        TcsResult recv_res = tcs_receive(ev[i].socket, user->buf + user->end,
                                         RECV_BUFSIZE - user->end,
                                         TCS_FLAG_NONE, &received_size);
        if (recv_res != TCS_SUCCESS) {
          LOG_DEBUG("disconnect\n");
          disconnect(poll, ev[i].socket, ev[i].user_data);
          continue;
        }
        user->end += received_size;

        if (received_size == 0) {
          continue;
        }
        int looping = 1;
        while (looping && (user->start + 4) <= user->end) {
          ClientMsgTag tag = *((ClientMsgTag *)(user->buf + user->start));
          switch (tag) {
          case ClientEmote: {
            ClientMsgEmote *msg;
            if (msg =
                    has_full_message(user, sizeof(ClientMsgEmote), &looping)) {
              struct __attribute__((packed)) {
                ServerMsgTag tag;
                ServerMsgEmote data;
              } server_msg = {
                  .tag = ServerEmote,
                  .data =
                      {
                          .id = user->id,
                          .index = msg->index,
                      },
              };
              broadcast((const uint8_t *)&server_msg, sizeof(server_msg),
                        pdata[user->pidx].meta.id);
            }
            break;
          }
          case ClientBeatGame: {
            ClientMsgBeatGame *msg;
            if (msg = has_full_message(user, sizeof(ClientMsgBeatGame),
                                       &looping)) {
              if (msg->duration < pdata[user->pidx].meta.best_time) {
                pdata[user->pidx].meta.best_time = msg->duration;
                // send a world update to other players
                struct __attribute__((packed)) {
                  ServerMsgTag tag;
                  ServerMsgPlayerMeta data;
                } msg = {
                    .tag = ServerPlayerMeta,
                    .data = pdata[user->pidx].meta,
                };
                broadcast((const uint8_t *)&msg, sizeof(msg),
                          pdata[user->pidx].meta.id);
              }
            }
            break;
          }
          case ClientSetName: {
            ClientMsgSetName *msg;
            if (msg = has_full_message(user, sizeof(ClientMsgSetName),
                                       &looping)) {
              strncpy(pdata[user->pidx].meta.name, msg->name, MAX_NAME_LEN);
              // send a world update to other players
              struct __attribute__((packed)) {
                ServerMsgTag tag;
                ServerMsgPlayerMeta data;
              } msg = {
                  .tag = ServerPlayerMeta,
                  .data = pdata[user->pidx].meta,
              };
              broadcast((const uint8_t *)&msg, sizeof(msg),
                        pdata[user->pidx].meta.id);
            }
            break;
          }
          case ClientBeachballScored: {
            int *who;
            if (who = has_full_message(user, sizeof(int), &looping)) {
              float this_distance =
                  pdata[user->pidx].data.distance_to_beachball;
              bool is_closest = true;
              for (size_t j = 0; j < MAX_CONNECTIONS; ++j) {
                if (!pdata[j].is_valid)
                  continue;
                if (pdata[j].meta.id == user->id)
                  continue;
                if (pdata[j].data.distance_to_beachball < this_distance) {
                  is_closest = false;
                  break;
                }
              }
              if (is_closest) {
                struct __attribute__((packed)) {
                  ServerMsgTag tag;
                  int who;
                } server_msg = {
                    .tag = ServerBeachballScored,
                    .who = *who,
                };
                broadcast((const uint8_t *)&server_msg, sizeof(server_msg),
                          UINT64_MAX);
                meta.score[(*who > 0) ? 0 : 1]++;
                printf("new score: %d:%d\n", meta.score[0], meta.score[1]);
                broadcast_meta();
              }
            }
            break;
          }
          case ClientResetBeachballScore: {
            if (has_full_message(user, 0, &looping)) {
              memset(&meta.score, 0, sizeof(meta.score));
              broadcast_meta();
            }
          }
          case ClientUpdateBeachball: {
            ClientMsgUpdate *msg;
            if (msg =
                    has_full_message(user, sizeof(ClientMsgUpdate), &looping)) {
              struct __attribute__((packed)) {
                ServerMsgTag tag;
                ServerMsgUpdateBeachball data;
              } server_msg = {
                  .tag = ServerUpdateBeachball,
                  .data.stuff = *msg,
              };
              broadcast((const uint8_t *)&server_msg, sizeof(server_msg),
                        pdata[user->pidx].meta.id);
            }
            break;
          }
          case ClientUpdate: {
            ClientMsgUpdate *msg;
            if (msg =
                    has_full_message(user, sizeof(ClientMsgUpdate), &looping)) {
              // do something with the message
              pdata[user->pidx].data = *msg;

              LOG_DEBUG("Sending world update to %llu\n", user->id);
              // send a world update to this player
              for (size_t j = 0; j < MAX_CONNECTIONS; ++j) {
                if (!pdata[j].is_valid)
                  continue;
                if (pdata[j].meta.id == user->id)
                  continue;
                struct __attribute__((packed)) {
                  ServerMsgTag tag;
                  ServerMsgUpdatePlayer data;
                } msg = {.tag = ServerUpdatePlayer,
                         .data = {
                             .id = pdata[j].meta.id,
                             .stuff = pdata[j].data,
                         }};
                tcs_send(ev[i].socket, (const uint8_t *)&msg, sizeof(msg),
                         TCS_MSG_SENDALL, NULL);
              }
              LOG_DEBUG("got update\n\tx: %f\n\ty: %f\n\tz: %f\n", msg->px,
                        msg->py, msg->pz);
            }
            break;
          }
          default: {
            printf("WEIRD STATE DETECTED %llu [%lu, %lu]\n", user->id,
                   user->start, user->end);
            disconnect(poll, ev[i].socket, ev[i].user_data);
            looping = 0;
            break;
          }
          }
        }
        // reset buffer
        if (user->start == user->end) {
          user->start = 0;
          user->end = 0;
        }
        // shift remaining garbage to the front of the buffer
        else if (user->start && user->start < user->end) {
          printf("FRAGMENTED MESSAGE %llu: [%lu, %lu]\n", user->id, user->start,
                 user->end);
          memmove(user->buf, user->buf + user->start, user->end - user->start);
          user->end = user->end - user->start;
          user->start = 0;
        }
      }
    }
  }

  if (tcs_close(&listen_socket) != TCS_SUCCESS)
    return show_error("Could not close socket");

  if (tcs_lib_cleanup() != TCS_SUCCESS)
    return show_error("Could not free tinycsocket");
}
