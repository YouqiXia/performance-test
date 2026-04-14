#ifndef BAREMETAL_CASE_HTIF_STDIO_H
#define BAREMETAL_CASE_HTIF_STDIO_H

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

long htif_proxy_syscall(long which, uintptr_t a0, uintptr_t a1, uintptr_t a2);
void htif_exit(int code) __attribute__((noreturn));
size_t htif_write_fd(int fd, const void* buf, size_t len);
size_t htif_write(const void* buf, size_t len);

int vsnprintf(char* out, size_t n, const char* fmt, va_list ap);
int snprintf(char* out, size_t n, const char* fmt, ...);
int printf(const char* fmt, ...);
int fprintf(FILE* stream, const char* fmt, ...);
int puts(const char* s);
int putchar(int ch);
void perror(const char* s);

void* memcpy(void* dest, const void* src, size_t len);
void* memset(void* dest, int value, size_t len);
size_t strlen(const char* s);
int strcmp(const char* lhs, const char* rhs);
char* strcpy(char* dest, const char* src);

void* malloc(size_t size);
void free(void* ptr);
int posix_memalign(void** memptr, size_t alignment, size_t size);
void* calloc(size_t n, size_t size);
void* realloc(void* ptr, size_t size);

void srand(unsigned seed);
int rand(void);
void qsort(void* base, size_t nmemb, size_t size,
           int (*compar)(const void*, const void*));

FILE* fopen(const char* path, const char* mode);
int fclose(FILE* stream);

#endif
