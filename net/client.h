#define TINYCSOCKET_IMPLEMENTATION
#include "interop.h"
#include "tinycsocket.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int show_error(const char *error_text) {
  fprintf(stderr, "%s\n", error_text);
  return -1;
}

#define RECV_BUFSIZE 1024

typedef struct UserData {
  int looping;
  size_t start;
  size_t end;
  uint8_t buf[RECV_BUFSIZE];
} UserData;

char saved_conn_str[256] = {};
int connected = 0;
time_t disconnected_at = 0;
struct TcsPoll *tcs_poll = NULL;
TcsSocket client_socket = TCS_SOCKET_INVALID;
UserData user = {};
struct TcsPollEvent ev[1] = {};

bool badcop_is_connected() { return connected; }

void _set_connected(int conn) {
  if (connected == conn)
    return;
  connected = conn;
  if (!connected) {
    disconnected_at = time(NULL);
    // set a timer so we can reconnect
  }
}

void *has_full_message(size_t n) {
  if (user.end < user.start + n + sizeof(ServerMsgTag)) {
    // reset buffer
    if (user.start == user.end) {
      user.start = 0;
      user.end = 0;
    }
    // shift remaining garbage to the front of the buffer
    else if (user.start && user.start < user.end) {
      memmove(user.buf, user.buf + user.start, user.end - user.start);
      user.end = user.end - user.start;
      user.start = 0;
    }
    user.looping = 0;
    return NULL;
  }
  void *ret = user.buf + user.start;
  user.start += n + sizeof(ServerMsgTag);
  return ret;
}

TcsResult badcop_send_beachball_scored(int who) {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
    int data;
  } msg = {.tag = ClientBeachballScored, .data = who};
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}
TcsResult badcop_send_beachball_update(ClientMsgUpdate update) {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
    ClientMsgUpdate data;
  } msg = {.tag = ClientUpdateBeachball, .data = update};
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}

TcsResult badcop_send_update(ClientMsgUpdate update) {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
    ClientMsgUpdate data;
  } msg = {.tag = ClientUpdate, .data = update};
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}

TcsResult badcop_emote(int index) {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
    ClientMsgEmote data;
  } msg = {
      .tag = ClientEmote,
      .data =
          {
              .index = index,
          },
  };
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}

TcsResult badcop_set_name(const char *name) {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
    ClientMsgSetName data;
  } msg = {
      .tag = ClientSetName,
      .data = {0},
  };
  strncpy(msg.data.name, name, MAX_NAME_LEN);
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}

TcsResult badcop_reset_beachball_score() {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
  } msg = {
      .tag = ClientResetBeachballScore,
  };
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}

TcsResult badcop_beat_game(unsigned long long duration) {
  struct __attribute__((packed)) {
    ClientMsgTag tag;
    ClientMsgBeatGame data;
  } msg = {
      .tag = ClientBeatGame,
      .data = {.duration = duration},
  };
  TcsResult res = tcs_send(client_socket, (const uint8_t *)&msg, sizeof(msg),
                           TCS_MSG_SENDALL, NULL);
  if (res != TCS_SUCCESS) {
    _set_connected(0);
  }
  return res;
}

/***
 * Read from the actual TCP socket; don't call this directly (see 'poll_msg')
 */
void _recv_next() {
  if (!connected)
    return;
  size_t events;
  TcsResult poll_res = tcs_poll_wait(tcs_poll, ev, 1, &events, 0);
  if (events && ev[0].can_read) {
    size_t received_size = 0;
    TcsResult res =
        tcs_receive(client_socket, user.buf + user.end, RECV_BUFSIZE - user.end,
                    TCS_FLAG_NONE, &received_size);
    switch (res) {
    case TCS_SUCCESS:
      user.end += received_size;
      if (received_size) {
        user.looping = 1;
      }
      break;
    default:
      _set_connected(0);
      break;
    }
  }
  if (events && ev[0].error) {
    printf("Socket read error: %d\n", ev[0].error);
    _set_connected(0);
  }
}

int badcop_init(char *conn_str);

/***
 * Get one message from the server.
 * Returns NULL if there are no more messages available.
 */
void *badcop_poll_msg() {
  if (!connected) {
    // let's see if we should reconnect
    time_t timestamp = time(NULL);
#define RECONNECT_AFTER 5
    // #define RECONNECT_AFTER 60000
    if (timestamp - disconnected_at >= RECONNECT_AFTER) {
      printf("Attempting reconnect\n");
      badcop_init(saved_conn_str);
    }
    return NULL;
  }
  if (!user.looping) {
    _recv_next();
    if (!user.looping) {
      return NULL;
    }
  }
  if (user.looping && user.start + 4 <= user.end) {
    void *msg;
    ServerMsgTag tag = *((ServerMsgTag *)(user.buf + user.start));
    switch (tag) {
    case ServerEmote:
      if (msg = has_full_message(sizeof(ServerMsgEmote)))
        return msg;
      break;
    case ServerUpdatePlayer:
      if (msg = has_full_message(sizeof(ServerMsgUpdatePlayer)))
        return msg;
      break;
    case ServerUpdateBeachball:
      if (msg = has_full_message(sizeof(ServerMsgUpdateBeachball)))
        return msg;
      break;
    case ServerConnected:
      if (msg = has_full_message(sizeof(ServerMsgConnected)))
        return msg;
      break;
    case ServerPlayerMeta:
      if (msg = has_full_message(sizeof(ServerMsgPlayerMeta)))
        return msg;
      break;
    case ServerBeachballScored:
      if (msg = has_full_message(sizeof(int)))
        return msg;
      break;
    case ServerDisconnected:
      if (msg = has_full_message(sizeof(ServerMsgDisconnected)))
        return msg;
      break;
    case ServerMeta:
      if (msg = has_full_message(sizeof(ServerMsgMeta)))
        return msg;
      break;
    default:
      printf("server sent garbage or i (badcop) am bad at C: tag = %d\n", tag);
      return NULL;
    }
  } else if (user.looping) {
    // reset buffer
    if (user.start == user.end) {
      user.start = 0;
      user.end = 0;
    }
    // shift remaining garbage to the front of the buffer
    else if (user.start && user.start < user.end) {
      memmove(user.buf, user.buf + user.start, user.end - user.start);
      user.end = user.end - user.start;
      user.start = 0;
    }
    user.looping = 0;
  }
  return NULL;
}

/***
 * Call to open a socket to the server.
 */
int badcop_init(char *conn_str) {
  printf("connecting to %s\n", conn_str);
  disconnected_at = time(NULL);
  if (!*saved_conn_str) {
    strncpy(saved_conn_str, conn_str, 255);
    tcs_poll_create(&tcs_poll);
  } else {
    tcs_poll_remove(tcs_poll, client_socket);
  }
  user = (UserData){};
  _set_connected(0);
  client_socket = TCS_SOCKET_INVALID;
  if (tcs_lib_init() != TCS_SUCCESS)
    return show_error("Could not init tinycsocket");

  if (tcs_socket_tcp_str(&client_socket, NULL, conn_str, 10000) != TCS_SUCCESS)
    return show_error("Could not create a socket");

  _set_connected(1);

#ifndef __EMSCRIPTEN__
  tcs_opt_nonblocking_set(client_socket, true);
  tcs_opt_ip_no_delay_set(client_socket, true);
#endif

  tcs_poll_add(tcs_poll, client_socket, NULL, TCS_POLL_READ);
}

/***
 * don't call this why would you ever do that
 */
int cleanup() {
  if (tcs_shutdown(client_socket, TCS_SHUTDOWN_BOTH) != TCS_SUCCESS)
    return show_error("Could not shutdown socket");

  if (tcs_close(&client_socket) != TCS_SUCCESS)
    return show_error("Could not close the socket");

  if (tcs_lib_cleanup() != TCS_SUCCESS)
    return show_error("Could not free tinycsocket");
}
