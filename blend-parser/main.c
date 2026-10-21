#include "./blend.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const char *type_name;
  Blend_Path path;
  bool dump_bytes;
} DumpBlockWithTypeArgs;

bool dump_block_with_addr(void *data_void, Blend_Block *block) {
  void *ptr = *(void **)data_void;
  if (block->old == ptr) {
    fprintf(stdout, "%p + %zu = %p: \n", block->old, block->body_length,
            block->old + block->body_length);
    Blend_Obj obj = Blend_Block_as_obj(block);
    Blend_Obj_dump(stderr, obj);
    fprintf(stderr, " :: ");
    Blend_Full_Type_dump(stderr, obj.type);
    fprintf(stderr, "\n");
  }
  return true;
}
bool dump_block_with_type(void *data_void, Blend_Block *block) {
  const DumpBlockWithTypeArgs *data = data_void;
  if (block) {
    if (strcmp(block->type->name, data->type_name) == 0) {
      fprintf(stdout, "%p + %zu = %p: \n", block->old, block->body_length,
              block->old + block->body_length);
      Blend_Obj obj = Blend_Obj_get_path(Blend_Block_as_obj(block), data->path);
      if (data->dump_bytes) {
        size_t size = Blend_Full_Type_size(obj.type);
        fwrite(obj.data, 1, size, stdout);
        fprintf(stdout, "\n");
      } else {
        Blend_Obj_dump(stderr, obj);
      }
      fprintf(stderr, "\n");
    }
  }
  return true;
}

bool dump_block(void *data, Blend_Block *block) {
  (void)data;
  Blend_Block_dump(stderr, block);
  fprintf(stderr, "\n");
  return true;
}

void run(Blend *blend, int argc, const char *argv[]) {
  if (argc >= 3 && strcmp(argv[2], "--generate-bindings") == 0) {

    FILE *output = stdout;
    if (argc >= 4) {
      const char *output_path = argv[3];
      output = fopen(output_path, "w");
      if (output == NULL) {
        fprintf(stderr, "Failed to create %s\n", output_path);
        exit(1);
      }
    }
    Blend_generate_bindings(blend, output);
    if (output != stdout) {
      fclose(output);
    }
    return;
  }
  if (argc >= 3 && strcmp(argv[2], "--dump-type") == 0) {
    if (argc < 4) {
      fprintf(stderr, "give name of the type\n");
      exit(1);
    }
    const char *type_name = argv[3];
    Blend_Type *type = Blend_find_type(blend, Blend_String_of_c(type_name));
    Blend_Type_dump(stderr, type);
    fprintf(stderr, "\n");
    return;
  }
  if (argc >= 3 && strcmp(argv[2], "--dump-block-at") == 0) {
    if (argc < 4) {
      fprintf(stderr, "you forgot addr");
    }
    void *addr = (void *)strtoull(argv[3], NULL, 16);
    fprintf(stderr, "Looking for addr %p\n", addr);
    Blend_find_all_blocks(blend, dump_block_with_addr, &addr);
    return;
  }
  if (argc >= 3 && strcmp(argv[2], "--dump-blocks-with-type") == 0) {
    if (argc < 4) {
      fprintf(stderr, "you forgot the type\n");
      exit(1);
    } else {
      Blend_Path path = {
          .head = NULL,
      };
      bool dump_bytes = false;
      if (argc >= 5) {
        path = Blend_Path_parse(argv[4]);
      }
      if (argc >= 6 && strcmp(argv[5], "--dump-bytes") == 0) {
        dump_bytes = true;
      }
      DumpBlockWithTypeArgs data = {
          .type_name = argv[3],
          .path = path,
          .dump_bytes = dump_bytes,
      };
      Blend_find_all_blocks(blend, dump_block_with_type, &data);
      Blend_Path_drop(path);
    }
    return;
  }
  if (argc >= 3 && strcmp(argv[2], "--dump-blocks") == 0) {
    if (argc < 4) {
      Blend_find_all_blocks(blend, dump_block, NULL);
    } else {
      const char *code = argv[3];
      Blend_find_all_blocks_with_code(blend, code, dump_block, NULL);
    }
    return;
  }
  fprintf(stderr, "failed to parse args");
  exit(1);
}

int main(int argc, const char **argv) {
  if (argc < 2) {
    fprintf(stderr, "Usage: ./test <file.blend>");
    exit(1);
  }
  const char *path = argv[1];
  Blend *blend = Blend_load(path);
  run(blend, argc, argv);
  Blend_drop(blend);
  return 0;
}
