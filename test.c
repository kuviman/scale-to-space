#include <GL/glew.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_video.h>
#include <math.h>
#include <stdio.h>

int main(int argc, char **argv) {
  if (!SDL_Init(SDL_INIT_VIDEO)) {
    fprintf(stderr, "Failed to init: %s", SDL_GetError());
    return -1;
  }
#if defined(__APPLE__)
  // GL 3.2 Core + generally GLSL 150
  SDL_GL_SetAttribute(
      SDL_GL_CONTEXT_FLAGS,
      SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
#else
  // GL 3.0 + generally GLSL 130
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, 0);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#endif
  SDL_Window *window = SDL_CreateWindow("TEST", 0, 0, SDL_WINDOW_OPENGL);
  if (window == NULL) {
    fprintf(stderr, "Failed to create window: %s", SDL_GetError());
    return -1;
  }
  SDL_GLContext gl = SDL_GL_CreateContext(window);
  if (gl == NULL) {
    fprintf(stderr, "Failed to create gl context: %s", SDL_GetError());
    return -1;
  }
  if (!SDL_GL_MakeCurrent(window, gl)) {
    fprintf(stderr, "Failed to SDL_GL_MakeCurrent: %s", SDL_GetError());
    return -1;
  }
  GLenum glew_result = glewInit();
  if (glew_result != GLEW_OK) {
    fprintf(stderr, "Failed to glewInit: %s", glewGetErrorString(glew_result));
    return -1;
  }
  bool running = true;
  while (running) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
      switch (event.type) {
      SDL_EVENT_QUIT: {
        running = false;
        break;
      }
      }
    }
    float t = ((float)SDL_GetTicks()) / 1000.0;
    t = t - floorf(t);
    glClearColor(t, t, t, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    if (!SDL_GL_SwapWindow(window)) {
      fprintf(stderr, "Failed to SDL_GL_SwapWindow: %s", SDL_GetError());
      return -1;
    }
  }
  SDL_Quit();
}
