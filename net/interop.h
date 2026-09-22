typedef enum ServerMsgTag {
  ServerUpdatePlayer,
  ServerUpdateBeachball,
  ServerConnected,
  ServerDisconnected,
  ServerMeta,
  ServerPlayerMeta,
  ServerEmote,
  ServerBeachballScored
} ServerMsgTag;

typedef enum ClientMsgTag {
  ClientUpdate,
  ClientUpdateBeachball,
  ClientBeachballScored,
  ClientBeatGame,
  ClientSetName,
  ClientEmote,
  ClientResetBeachballScore
} ClientMsgTag;

typedef struct __attribute__((packed)) {
  int score[2];
} ServerMsgMeta;

typedef struct __attribute__((packed)) {
  int index;
  unsigned long long id;
} ServerMsgEmote;

typedef struct __attribute__((packed)) {
  unsigned long long id;
} ServerMsgConnected;

typedef struct __attribute__((packed)) {
  unsigned long long id;
} ServerMsgDisconnected;

typedef struct __attribute__((packed)) {
  float px;
  float py;
  float pz;
  float vx;
  float vy;
  float vz;
  float rx;
  float ry;
  float rz;
  float rw;
  struct __attribute__((packed)) {
    float x;
    float y;
    float z;
  } angular_vel;
  int skin;
  int jetpack;
  float scale;
  float distance_to_beachball;
} ClientMsgUpdate;

typedef struct __attribute__((packed)) {
  unsigned long long duration;
} ClientMsgBeatGame;

typedef struct __attribute__((packed)) {
  int index;
} ClientMsgEmote;

#define MAX_NAME_LEN 27
typedef struct __attribute__((packed)) {
  char name[MAX_NAME_LEN + 1];
} ClientMsgSetName;

typedef struct __attribute__((packed)) {
  unsigned long long id;
  unsigned long long best_time;
  char name[MAX_NAME_LEN + 1];
} ServerMsgPlayerMeta;

typedef struct __attribute__((packed)) {
  unsigned long long id;
  ClientMsgUpdate stuff;
} ServerMsgUpdatePlayer;

typedef struct __attribute__((packed)) {
  ClientMsgUpdate stuff;
} ServerMsgUpdateBeachball;
