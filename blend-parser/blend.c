#include <ctype.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>

#include "./blend.h"

Blend_LogLevel MAX_LOG_LEVEL = Blend_LogLevel_info;

void print_log(Blend_LogLevel log_level, const char *fmt, ...) {
  if (log_level > MAX_LOG_LEVEL) {
    return;
  }
  fprintf(stderr, "[blend] ");
  va_list va;
  va_start(va, fmt);
  vfprintf(stderr, fmt, va);
  va_end(va);
  fprintf(stderr, "\n");
}

#define log_info(...) print_log(Blend_LogLevel_info, __VA_ARGS__)
#define log_trace(...) print_log(Blend_LogLevel_trace, __VA_ARGS__)

noreturn void panic(const char *fmt, ...) {
  fprintf(stderr, "[blend] PANIC: ");
  va_list va;
  va_start(va, fmt);
  vfprintf(stderr, fmt, va);
  va_end(va);
  fprintf(stderr, "\n");
  exit(1);
}

void *try_raw_malloc(size_t size) {
  if (size == 0) {
    return NULL;
  }
  void *result = malloc(size);
  if (result == NULL) {
    panic("Failed to malloc %zu bytes", size);
  }
  return result;
}

#define try_malloc(name) name = try_raw_malloc(sizeof(*name))
#define try_malloc_array(name, len) name = try_raw_malloc(sizeof(name[0]) * len)

typedef struct {
  const uint8_t *data;
  size_t data_size;
  size_t offset;
} Reader;

const void *Reader_read_nocopy(Reader *reader, size_t size, const char *what) {
  if (reader->offset + size > reader->data_size) {
    panic("While reading %s: "
          "expected to read %zu bytes at offset %zu (data size = %zu)",
          what, size, reader->offset, reader->data_size);
  }
  const void *result = reader->data + reader->offset;
  reader->offset += size;
  return result;
}

void Reader_read(Reader *reader, void *ptr, size_t size, const char *what) {
  memcpy(ptr, Reader_read_nocopy(reader, size, what), size);
}

void Reader_read_magic(Reader *reader, const char *magic) {
  size_t len = strlen(magic);
  const char *data = Reader_read_nocopy(reader, len, magic);
  if (strncmp(data, magic, len) != 0) {
    panic("Expected magic %s, got %.*s", magic, (int)len, data);
  }
}

uint8_t Reader_read_byte(Reader *reader, const char *what) {
  uint8_t value;
  Reader_read(reader, &value, sizeof(value), what);
  return value;
}

uint16_t Reader_read_uint16(Reader *reader, const char *what) {
  uint16_t value;
  Reader_read(reader, &value, sizeof(value), what);
  return value;
}

uint32_t Reader_read_uint32(Reader *reader, const char *what) {
  uint32_t value;
  Reader_read(reader, &value, sizeof(value), what);
  return value;
}

uint64_t Reader_read_uint64(Reader *reader, const char *what) {
  uint64_t value;
  Reader_read(reader, &value, sizeof(value), what);
  return value;
}

void Reader_align(Reader *reader, size_t alignment) {
  reader->offset += (alignment - reader->offset) % alignment;
  if (reader->offset > reader->data_size) {
    panic("reader aligned past the end of data");
  }
}

Blend_Header read_header(Reader *reader) {
  Blend_Header header;
  Reader_read_magic(reader, "BLENDER");
  size_t header_size;
  {
    char header_size_str[3];
    Reader_read(reader, header_size_str, 2, "header size");
    header_size_str[2] = '\0';
    if (!isdigit(header_size_str[0]) || !isdigit(header_size_str[1])) {
      panic("Expected 2 digits for header size, got %s", header_size_str);
    }
    header_size = atoi(header_size_str);
  }
  log_trace("Header size = %zu", header_size);
  {
    uint8_t byte = Reader_read_byte(reader, "pointer size");
    if (byte != '-') {
      panic("Expected '-', got 0x%02X", (int)byte);
    }
  }
  {
    char blend_file_format_version_str[2];
    Reader_read(reader, blend_file_format_version_str, 2,
                "blend file format version");
    if (strncmp(blend_file_format_version_str, "01", 2) != 0) {
      panic("Expected 01 as blend file format version, got %.*s", 2,
            blend_file_format_version_str);
    }
  }
  {
    uint8_t byte = Reader_read_byte(reader, "endianness");
    if (byte != 'v') {
      panic("Expected 'v', got 0x%02X", (int)byte);
    }
  }
  {
    char file_version[4];
    Reader_read(reader, file_version, sizeof(file_version), "file version");
    for (size_t i = 0; i < sizeof(file_version); i++) {
      if (!isdigit(file_version[i])) {
        panic("Expected file version to be all digits, got %.*s",
              (int)sizeof(file_version), (const char *)file_version);
      }
    }
    log_info("file version: %.*s", (int)sizeof(file_version),
             (const char *)file_version);
  }
  size_t read_size = reader->offset;
  if (read_size != header_size) {
    panic("Wrong header size: expected %zu, got %zu", header_size, read_size);
  };
  return header;
}

Blend_Block read_block(Reader *reader) {
  log_trace("reading block");
  /* code is size 8 because version is 01 and ptr size is 8 */
  Blend_Block block;
  Reader_read(reader, block.code, sizeof(block.code), "block code");
  log_trace("code = %.*s", (int)sizeof(block.code), block.code);
  block.sdna_index = Reader_read_uint32(reader, "block sdna index");
  log_trace("sdna index = %u", block.sdna_index);
  uint64_t old = Reader_read_uint64(reader, "block mem addr");
  log_trace("mem_addr = %llu", (unsigned long long int)old);
  block.body_length = Reader_read_uint64(reader, "block body length");
  log_trace("body length = %zu", block.body_length);
  block.count = Reader_read_uint64(reader, "block count");
  log_trace("count = %zu", block.count);
  block.body = Reader_read_nocopy(reader, block.body_length, "block body");
  return block;
}

Blend_DNA_Name parse_name(const char *s) {
  const char *original_s = s;
  Blend_Type_Qualifiers qualifiers = {
      .is_fn = false,
      .ptr_order = 0,
      .array_len = 0,
      .array_order = 0,
  };
  if (strchr(s, '(') != NULL) {
    qualifiers.is_fn = true;
    return (Blend_DNA_Name){
        .qualifiers = qualifiers,
        .name = Blend_String_of_c(s),
    };
  }
  while (*s == '*') {
    qualifiers.ptr_order++;
    s++;
  }
  Blend_String name;
  const char *array_open = strchr(s, '[');
  if (array_open != NULL) {
    name = (Blend_String){
        .s = s,
        .length = array_open - s,
    };
    size_t max_array_nestiness =
        sizeof(qualifiers.array_len) / sizeof(qualifiers.array_len[0]);
    s = array_open;
    while (*s) {
      if (*s != '[') {
        panic("expected '[': %s", original_s);
      }
      if (qualifiers.array_order >= max_array_nestiness) {
        panic("too much nestiness of array: %s", original_s);
      }
      s++;
      char *end;
      qualifiers.array_len[qualifiers.array_order++] = strtol(s, &end, 10);
      if (*end != ']') {
        panic("array size didnt end with ']': %s", original_s);
      }
      s = end + 1;
    }
  } else {
    name = (Blend_String){
        .s = s,
        .length = strlen(s),
    };
  }
  return (Blend_DNA_Name){
      .name = name,
      .qualifiers = qualifiers,
  };
}

Blend_DNA parse_dna(Blend_Block block) {
  Blend_DNA dna;
  Reader reader_value = {
      .data = block.body,
      .data_size = block.body_length,
      .offset = 0,
  };
  Reader *reader = &reader_value;
  Reader_read_magic(reader, "SDNA");
  Reader_read_magic(reader, "NAME");
  dna.names_len = Reader_read_uint32(reader, "dna names len");
  try_malloc_array(dna.names, dna.names_len);
  for (size_t i = 0; i < dna.names_len; i++) {
    const char *name_raw = (const char *)(reader->data + reader->offset);
    dna.names[i] = parse_name(name_raw);
    reader->offset += strlen(name_raw) + 1;
    // log_trace("name: %s", dna.names[i]);
  }
  Reader_align(reader, 4);
  Reader_read_magic(reader, "TYPE");
  dna.types_len = Reader_read_uint32(reader, "dna types len");
  try_malloc_array(dna.types, dna.types_len);
  for (size_t i = 0; i < dna.types_len; i++) {
    dna.types[i].name = (const char *)(reader->data + reader->offset);
    reader->offset += strlen(dna.types[i].name) + 1;
    log_trace("type: %s", dna.types[i]);
  }
  Reader_align(reader, 4);
  Reader_read_magic(reader, "TLEN");
  for (size_t i = 0; i < dna.types_len; i++) {
    dna.types[i].size = Reader_read_uint16(reader, "dna type size");
    log_trace("type %s (size = %zu)", dna.types[i].name, dna.types[i].size);
  }
  Reader_align(reader, 4);
  Reader_read_magic(reader, "STRC");
  for (size_t i = 0; i < dna.types_len; i++) {
    dna.types[i].struct_def = NULL;
  }
  dna.structs_len = Reader_read_uint32(reader, "dna num structs");
  try_malloc_array(dna.structs, dna.structs_len);
  for (size_t i = 0; i < dna.structs_len; i++) {
    Blend_Struct *def = &dna.structs[i];
    size_t type_idx = Reader_read_uint16(reader, "dna struct type idx");
    def->type = &dna.types[type_idx];
    def->type->struct_def = def;
    def->fields_len = Reader_read_uint16(reader, "dna struct num fields");
    try_malloc_array(def->fields, def->fields_len);
    size_t offset = 0;
    for (size_t field_idx = 0; field_idx < def->fields_len; field_idx++) {
      size_t field_type_idx =
          Reader_read_uint16(reader, "dna struct field type idx");
      size_t field_name_idx =
          Reader_read_uint16(reader, "dna struct field name idx");
      if (field_type_idx >= dna.types_len) {
        panic("type idx oob");
      }
      if (field_name_idx >= dna.names_len) {
        panic("name idx oob");
      }
      Blend_Type_Field *field_type = &def->fields[field_idx];
      field_type->name = dna.names[field_name_idx].name;
      field_type->type = (Blend_Full_Type){
          .inner = &dna.types[field_type_idx],
          .qualifiers = dna.names[field_name_idx].qualifiers,
      };
      field_type->offset = offset;
      offset += Blend_Full_Type_size(field_type->type);
    }
  }
  return dna;
}

Blend_String read_file_to_end(const char *path) {
  FILE *file = fopen(path, "r");
  if (file == NULL) {
    panic("Failed to open file %s", path);
  }
  size_t file_size;
  if (fseek(file, 0, SEEK_END) != 0) {
    panic("Failed to fseek");
  }
  file_size = ftell(file);
  if (fseek(file, 0, SEEK_SET) != 0) {
    panic("Failed to fseek");
  }
  log_trace("file size = %zu", file_size);
  void *data = try_raw_malloc(file_size);
  size_t read = fread(data, 1, file_size, file);
  if (read != file_size) {
    panic("Failed to read full file of size %zu, only read %zu", file_size,
          read);
  }
  fclose(file);
  return (Blend_String){
      .s = data,
      .length = file_size,
  };
}

Blend *Blend_parse(const char *path) {
  log_trace("Loading %s", path);
  Blend *blend = malloc(sizeof(Blend));
  if (blend == NULL) {
    panic("OOM");
  }
  Blend_String file_contents = read_file_to_end(path);
  blend->data = (void *)file_contents.s;
  Reader reader = {
      .data = blend->data,
      .data_size = file_contents.length,
      .offset = 0,
  };
  read_header(&reader);
  blend->block_list = NULL;
  bool parsed_dna = false;
  while (reader.offset != reader.data_size) {
    BlockListNode *old = blend->block_list;
    try_malloc(blend->block_list);
    Blend_Block block = read_block(&reader);
    if (strncmp(block.code, "DNA1", sizeof(block.code)) == 0) {
      if (parsed_dna) {
        panic("multiple dnas???");
      }
      blend->dna = parse_dna(block);
      parsed_dna = true;
    }
    blend->block_list->block = block;
    blend->block_list->next = old;
  }
  {
    BlockListNode *node = blend->block_list;
    while (node != NULL) {
      Blend_Block *block = &node->block;
      if (block->sdna_index >= blend->dna.types_len) {
        panic("block dna index oob");
      }
      block->type = blend->dna.structs[block->sdna_index].type;
      node = node->next;
    }
  }
  log_info("Successfully loaded %s", path);
  return blend;
}

void Blend_drop(Blend *blend) {
  free((void *)blend->data);
  BlockListNode *node = blend->block_list;
  while (node != NULL) {
    BlockListNode *next = node->next;
    free(node);
    node = next;
  }
  free(blend->dna.names);
  for (size_t i = 0; i < blend->dna.types_len; i++) {
    Blend_Type *type = &blend->dna.types[i];
  }
  free(blend->dna.types);
  for (size_t i = 0; i < blend->dna.structs_len; i++) {
    Blend_Struct *def = &blend->dna.structs[i];
    free(def->fields);
  }
  free(blend->dna.structs);
  free(blend);
}

Blend_Type *Blend_find_type(Blend *blend, const char *name) {
  for (size_t i = 0; i < blend->dna.types_len; i++) {
    Blend_Type *type = &blend->dna.types[i];
    if (strcmp(type->name, name) == 0) {
      return type;
    }
  }
  panic("Failed to find type %s in blend", name);
}

int indent = 0;
int max_indent = 1;
bool indent_printed = false;

void print_indent_if_needed(FILE *out) {
  if (indent_printed) {
    return;
  }
  indent_printed = true;
  for (int i = 0; i < indent; i++) {
    fprintf(out, "  ");
  }
}

void println(FILE *out) {
  fprintf(out, "\n");
  indent_printed = false;
}

void Blend_String_dump_escaped(FILE *out, Blend_String s) {
  fprintf(out, "\"%.*s\"", (int)s.length, s.s);
}

void Blend_String_dump(FILE *out, Blend_String s) {
  fprintf(out, "%.*s", (int)s.length, s.s);
}

void Blend_Full_Type_dump(FILE *out, Blend_Full_Type type) {
  for (size_t i = 0; i < type.qualifiers.ptr_order; i++) {
    fprintf(out, "*");
  }
  Blend_Type_dump(out, type.inner);
  for (size_t i = 0; i < type.qualifiers.array_order; i++) {
    fprintf(out, "[%zu]", type.qualifiers.array_len[i]);
  }
}

void Blend_Type_dump(FILE *out, Blend_Type *type) {
  print_indent_if_needed(out);
  fprintf(out, "%s", type->name);
  if (indent >= max_indent) {
    return;
  }
  // fprintf(out, "(size=%zu)", type->size);
  if (type->struct_def != NULL) {
    fprintf(out, " {");
    indent++;
    if (indent <= max_indent) {
      for (size_t i = 0; i < type->struct_def->fields_len; i++) {
        if (i == 0) {
          println(out);
        }
        print_indent_if_needed(out);
        Blend_Type_Field *field = &type->struct_def->fields[i];
        Blend_String_dump(out, field->name);
        // fprintf(out, "(offset=%zu)", field->offset);
        fprintf(out, ": ");
        Blend_Full_Type_dump(out, field->type);
        fprintf(out, ",");
        println(out);
      }
    } else {
      fprintf(out, " ... ");
    }
    indent--;
    print_indent_if_needed(out);
    fprintf(out, "}");
  }
}

void Blend_find_all_blocks(Blend *blend,
                           void (*f)(void *user_data, Blend_Block *block),
                           void *user_data) {
  BlockListNode *node = blend->block_list;
  while (node != NULL) {
    f(user_data, &node->block);
    node = node->next;
  }
}

void Blend_find_all_blocks_with_code(Blend *blend, const char *code,
                                     void (*f)(void *user_data,
                                               Blend_Block *block),
                                     void *user_data) {
  BlockListNode *node = blend->block_list;
  while (node != NULL) {
    if (strncmp(node->block.code, code, sizeof(node->block.code)) == 0) {
      f(user_data, &node->block);
    }
    node = node->next;
  }
}
void Blend_Block_dump(FILE *out, Blend_Block *block) {
  fprintf(out, "%.*s: ", (int)sizeof(block->code), block->code);
  Blend_Type_dump(out, block->type);
}

Blend_Path Blend_Path_parse(const char *s) {
  log_trace("parsing path: %s", s);
  Blend_Path result;
  try_malloc(result.head);
  const char *dot_ptr = strchr(s, '.');
  if (dot_ptr == NULL) {
    *result.head = (Blend_PathSegment){
        .kind = Blend_PathSegmentKind_Field,
        .field =
            (Blend_String){
                .s = s,
                .length = strlen(s),
            },
        .next = NULL,
    };
  } else {
    *result.head = (Blend_PathSegment){
        .kind = Blend_PathSegmentKind_Field,
        .field =
            (Blend_String){
                .s = s,
                .length = dot_ptr - s,
            },
        .next = Blend_Path_parse(dot_ptr + 1).head,
    };
  }
  return result;
}

void Blend_Path_drop(Blend_Path path) {
  Blend_PathSegment *segment = path.head;
  while (segment != NULL) {
    Blend_PathSegment *next = segment->next;
    free(segment);
    segment = next;
  }
}

Blend_Obj Blend_Block_as_obj(Blend_Block *block) {
  return (Blend_Obj){
      .data = block->body,
      .type = block->type,
  };
}

int Blend_String_cmp(Blend_String as, Blend_String bs) {
  const char *a = as.s;
  size_t a_len = as.length;
  const char *b = bs.s;
  size_t b_len = bs.length;
  for (;;) {
    char char_a = a_len == 0 ? 0 : *a;
    char char_b = b_len == 0 ? 0 : *b;
    if (char_a == 0 && char_b == 0) {
      return 0;
    }
    if (char_a != char_b) {
      return (int)char_a - (int)char_b;
    }
    a++;
    a_len--;
    b++;
    b_len--;
  }
}

int strcmp_0_n(const char *a, const char *b, size_t b_len) {
  for (;;) {
    char char_a = *a;
    char char_b = b_len == 0 ? 0 : *b;
    if (char_a == 0 && char_b == 0) {
      return 0;
    }
    if (char_a != char_b) {
      return (int)char_a - (int)char_b;
    }
    a++;
    b++;
    b_len--;
  }
}

int str_Blend_String_cmp(const char *a, Blend_String b) {
  return strcmp_0_n(a, b.s, b.length);
}

Blend_Obj Blend_Obj_get_field(Blend_Obj obj, Blend_String field) {
  if (obj.type.qualifiers.array_order) {
    panic("getting field of array");
  }
  if (obj.type.qualifiers.ptr_order) {
    panic("getting field of ptr");
  }
  Blend_Type *type = obj.type.inner;
  if (type->struct_def == NULL) {
    panic("getting field of structs only is possible");
  }
  for (size_t i = 0; i < type->struct_def->fields_len; i++) {
    Blend_Type_Field *type_field = &type->struct_def->fields[i];
    if (Blend_String_cmp(type_field->name, field) == 0) {
      return (Blend_Obj){
          .data = obj.data + type_field->offset,
          .type = type_field->type,
      };
    }
  }
  panic("Could not find field %.*s in type %s", (int)field.length, field.s,
        type->name);
}

Blend_Obj Blend_Obj_index(Blend_Obj obj, size_t i) {
  if (obj.type.qualifiers.array_order == 0) {
    panic("Trying to index non-array obj");
  }
  size_t array_len = obj.type.qualifiers.array_len[0];
  if (i >= array_len) {
    panic("Out of bounds: index = %zu, array len = %zu", i, array_len);
  }
  Blend_Full_Type element_ty = obj.type;
  element_ty.qualifiers.array_order--;
  return (Blend_Obj){
      .data = obj.data + Blend_Full_Type_size(element_ty) * i,
      .type = element_ty,
  };
}

Blend_Obj Blend_Obj_get_path(Blend_Obj obj, Blend_Path path) {
  if (path.head == NULL) {
    return obj;
  }
  switch (path.head->kind) {
  case Blend_PathSegmentKind_Field: {
    return Blend_Obj_get_path(Blend_Obj_get_field(obj, path.head->field),
                              (Blend_Path){.head = path.head->next});
  }
  default: {
    panic("forgot to handle path segment kind: %d", path.head->kind);
  }
  }
}

size_t Blend_Full_Type_size(Blend_Full_Type type) {
  size_t size = type.inner->size;
  if (type.qualifiers.ptr_order) {
    size = sizeof(void *);
  }
  for (size_t i = 0; i < type.qualifiers.array_order; i++) {
    size *= type.qualifiers.array_len[i];
  }
  return size;
}

void Blend_Obj_dump(FILE *out, Blend_Obj obj) {
  if (obj.type.qualifiers.ptr_order) {
    fprintf(out, "<ptr> :: ");
    Blend_Full_Type_dump(out, obj.type);
    return;
  }
  if (obj.type.qualifiers.array_order) {
    if (obj.type.qualifiers.array_order == 1 &&
        strncmp(obj.type.inner->name, "char",
                obj.type.qualifiers.array_len[0]) == 0) {
      Blend_String_dump_escaped(out,
                                (Blend_String){
                                    .s = (const char *)obj.data,
                                    .length = obj.type.qualifiers.array_len[0],
                                });
      return;
    }
    fprintf(out, "[");
    indent++;
    if (indent <= max_indent) {
      for (size_t i = 0; i < obj.type.qualifiers.array_len[0]; i++) {
        if (i == 0) {
          println(out);
        }
        print_indent_if_needed(out);
        Blend_Obj_dump(out, Blend_Obj_index(obj, i));
        fprintf(out, ",");
        println(out);
      }
    } else {
      Blend_Full_Type element_ty = obj.type;
      element_ty.qualifiers.array_order--;
      fprintf(out, " ... :: ");
      Blend_Full_Type_dump(out, element_ty);
      fprintf(out, " ");
    }
    indent--;
    print_indent_if_needed(out);
    fprintf(out, "]");
    return;
  }
  Blend_Type *type = obj.type.inner;
  if (type->struct_def != NULL) {
    print_indent_if_needed(out);
    if (indent < max_indent) {
      fprintf(out, "{");
      indent++;
      for (size_t i = 0; i < type->struct_def->fields_len; i++) {
        if (i == 0) {
          println(out);
        }
        print_indent_if_needed(out);
        Blend_Type_Field *field = &type->struct_def->fields[i];
        fprintf(out, ".");
        Blend_String_dump(out, field->name);
        fprintf(out, " = ");
        Blend_Obj_dump(out, (Blend_Obj){
                                .data = obj.data + field->offset,
                                .type = field->type,
                            });
        fprintf(out, ",");
        println(out);
      }
      indent--;
      print_indent_if_needed(out);
      fprintf(out, "}");
    } else {
      fprintf(out, "<obj> :: ");
      Blend_Type_dump(out, type);
    }
  } else {
    if (strcmp(type->name, "char") == 0) {
      char c = *obj.data;
      if (isprint(c)) {
        fprintf(out, "'%c'", c);
      } else {
        fprintf(out, "'\\x%02X'", (int)c);
      }
      return;
    }
    fprintf(out, "<data> :: ");
    Blend_Type_dump(out, type);
  }
}

Blend_String Blend_String_of_c(const char *s) {
  return (Blend_String){
      .s = s,
      .length = strlen(s),
  };
}

const char *KAST_KEYWORDS[] = {"type", "str", "match", "module"};
const char *KAST_KEYWORDS_REPLACE[] = {"_type", "_str", "_match", "_module"};
Blend_String kast_ident(Blend_String ident) {
  for (size_t i = 0; i < sizeof(KAST_KEYWORDS) / sizeof(KAST_KEYWORDS[0]);
       i++) {
    const char *keyword = KAST_KEYWORDS[i];
    if (str_Blend_String_cmp(keyword, ident) == 0) {
      return Blend_String_of_c(KAST_KEYWORDS_REPLACE[i]);
    }
  }
  return ident;
}

void write_as_kast_type(FILE *out, Blend_Full_Type type) {
  for (size_t i = 0; i < type.qualifiers.array_order; i++) {
    fprintf(out, "Array[");
  }
  if (type.qualifiers.array_order > 0) {
    fprintf(out, "type (");
  }
  for (size_t i = 0; i < type.qualifiers.ptr_order; i++) {
    fprintf(out, "&");
  }
  fprintf(out, "%s", type.inner->name);
  if (type.qualifiers.array_order > 0) {
    fprintf(out, ")");
  }
  for (size_t i = type.qualifiers.array_order; i > 0;) {
    i--;
    fprintf(out, ", %zu]", type.qualifiers.array_len[i]);
  }
}

void generate_Type_bindings(FILE *out, Blend_Type *type) {
  fprintf(out, "const %s = ", type->name);
  if (type->struct_def != NULL) {
    fprintf(out, "newtype {\n");
    Blend_Struct *def = type->struct_def;
    for (size_t i = 0; i < def->fields_len; i++) {
      Blend_Type_Field *field = &def->fields[i];
      if (field->type.qualifiers.is_fn) {
        continue;
      }
      fprintf(out, "    .");
      Blend_String_dump(out, kast_ident(field->name));
      fprintf(out, " :: ");
      write_as_kast_type(out, field->type);
      fprintf(out, ",\n");
    }
    fprintf(out, "}");
  } else {
    // typedef struct name name;
    fprintf(out, "@opaque_type \"struct %s\"", type->name);
  }
  fprintf(out, ";\n");
}

char *dirname(const char *path) {
  const char *last_slash = strrchr(path, '/');
  char *result;
  if (last_slash == NULL) {
    result = try_raw_malloc(2);
    result[0] = '.';
    result[1] = '\0';
    return result;
  }
  result = try_raw_malloc(last_slash - path + 1);
  memcpy(result, path, last_slash - path);
  result[last_slash - path] = '\0';
  return result;
}

char *path_concat(const char *a, const char *b) {
  size_t a_len = strlen(a);
  size_t b_len = strlen(b);
  char *result = try_raw_malloc(a_len + 1 + b_len + 1);
  memcpy(result, a, a_len);
  result[a_len] = '/';
  memcpy(result + a_len + 1, b, b_len);
  result[a_len + 1 + b_len] = '\0';
  return result;
}

void Blend_generate_bindings(Blend *blend, FILE *out) {
  const char *prefix_path = "blend-parser/bindings_prefix.ks";
  Blend_String prefix_content = read_file_to_end(prefix_path);
  Blend_String_dump(out, prefix_content);
  free((void *)prefix_content.s);
  for (size_t i = 0; i < blend->dna.types_len; i++) {
    generate_Type_bindings(out, &blend->dna.types[i]);
  }
}
