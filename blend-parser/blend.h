#ifndef __BLEND_H_INCLUDED__
#define __BLEND_H_INCLUDED__

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/types.h>

typedef struct {
  const char *s;
  size_t length;
} Blend_String;

typedef struct Blend_StringMap Blend_StringMap;
Blend_StringMap *Blend_StringMap_new(void);
void Blend_StringMap_add(Blend_StringMap *map, Blend_String key, void *value);
void *Blend_StringMap_get(Blend_StringMap *map, Blend_String key);
void Blend_StringMap_drop(Blend_StringMap *map, void (*drop_value)(void *));

typedef struct {
  bool is_fn;
  size_t ptr_order;
  size_t array_order;
  size_t array_len[3];
} Blend_Type_Qualifiers;

typedef struct {
  struct Blend_Type *inner;
  Blend_Type_Qualifiers qualifiers;
} Blend_Full_Type;

typedef struct {
  Blend_String name;
  Blend_Full_Type type;
  size_t offset;
} Blend_Type_Field;

typedef struct {
  struct Blend_Type *type;
  size_t fields_len;
  Blend_Type_Field *fields;
} Blend_Struct;

typedef struct Blend_Type {
  const char *name;
  size_t size;
  Blend_Struct *struct_def;
} Blend_Type;

typedef enum { Blend_PathSegmentKind_Field } Blend_PathSegmentKind;

typedef struct Blend_PathSegment {
  Blend_PathSegmentKind kind;
  union {
    Blend_String field;
  };
  struct Blend_PathSegment *next;
} Blend_PathSegment;

typedef struct {
  Blend_PathSegment *head;
} Blend_Path;

typedef struct {
  Blend_String name;
  Blend_Type_Qualifiers qualifiers;
} Blend_DNA_Name;

typedef struct {
  size_t names_len;
  Blend_DNA_Name *names;
  size_t types_len;
  Blend_Type *types;
  size_t structs_len;
  Blend_Struct *structs;
} Blend_DNA;

typedef struct {
  char code[4];
  const uint8_t *body;
  size_t sdna_index;
  const uint8_t *old;
  Blend_Type *type;
  size_t count;
  size_t body_length;
} Blend_Block;

typedef enum {
  Blend_LogLevel_info,
  Blend_LogLevel_trace,
} Blend_LogLevel;

typedef struct Blend_BlockListNode Blend_BlockListNode;

struct Blend_BlockListNode {
  Blend_Block block;
  Blend_BlockListNode *next;
};

typedef struct {
} Blend_Header;

typedef struct {
  Blend_Header header;
  const uint8_t *data;
  Blend_BlockListNode *block_list;
  Blend_DNA dna;
} Blend;

typedef struct {
  const uint8_t *data;
  Blend_Full_Type type;
} Blend_Obj;

Blend *Blend_load(const char *path);
void Blend_drop(Blend *blend);

int str_Blend_String_cmp(const char *a, Blend_String b);
Blend_String Blend_String_of_c(const char *s);

Blend_Type *Blend_find_type(Blend *blend, Blend_String name);
void Blend_Type_dump(FILE *out, Blend_Type *type);
void Blend_Full_Type_dump(FILE *out, Blend_Full_Type type);

void Blend_find_all_blocks(Blend *blend,
                           bool (*f)(void *user_data, Blend_Block *block),
                           void *user_data);
void Blend_find_all_blocks_with_code(Blend *blend, const char *code,
                                     bool (*f)(void *user_data,
                                               Blend_Block *block),
                                     void *user_data);
void Blend_Block_dump(FILE *out, Blend_Block *block);
Blend_Obj Blend_Block_as_obj(Blend_Block *block);
void *Blend_Obj_as_ptr(Blend_Obj obj);
Blend_Obj Blend_Obj_ptr_add(Blend_Obj obj, size_t i);
Blend_Obj Blend_Obj_index(Blend_Obj obj, size_t i);
Blend_Obj Blend_Obj_get_field(Blend_Obj obj, Blend_String field);
Blend_Obj Blend_Obj_get_path(Blend_Obj obj, Blend_Path path);

Blend_Path Blend_Path_parse(const char *s);
void Blend_Path_drop(Blend_Path path);

void Blend_Obj_dump(FILE *out, Blend_Obj obj);
size_t Blend_Full_Type_size(Blend_Full_Type type);

void Blend_generate_bindings(Blend *blend, FILE *out);

#endif
