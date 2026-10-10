main.exe: main.c blend.c blend.h
	bash -c '$${CC:-gcc} -fsanitize=address,undefined,leak -g main.c blend.c -o main.exe'

