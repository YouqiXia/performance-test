#include "htif_stdio.h"

#include <stdbool.h>
#include <stdlib.h>
#include <sys/stat.h>

/*
 * Output path mirrors pk/frontend + pk/console:
 * 1. format locally with vsnprintf
 * 2. proxy a SYS_write request through HTIF to the host
 *
 * The HTIF magic-memory syscall protocol itself follows the same pattern
 * used by riscv-tests baremetal benchmarks.
 */

#define SYS_write 64
#define HTIF_STDOUT_FD 1
#define HTIF_STDERR_FD 2

#define BAREMETAL_HEAP_BYTES (16 * 1024 * 1024)

typedef struct {
  size_t size;
} alloc_header_t;

FILE *stdin = NULL;
FILE *stdout = (FILE *)(uintptr_t)HTIF_STDOUT_FD;
FILE *stderr = (FILE *)(uintptr_t)HTIF_STDERR_FD;

static unsigned rand_state = 1;
static unsigned char baremetal_heap[BAREMETAL_HEAP_BYTES];
static size_t baremetal_heap_off = 0;

volatile uint64_t tohost __attribute__((section(".tohost")));
volatile uint64_t fromhost __attribute__((section(".tohost")));

static inline void htif_fence(void)
{
  asm volatile ("fence iorw, iorw" ::: "memory");
}

long htif_proxy_syscall(long which, uintptr_t a0, uintptr_t a1, uintptr_t a2)
{
  volatile uint64_t magic_mem[8] __attribute__((aligned(64)));

  magic_mem[0] = (uint64_t)which;
  magic_mem[1] = (uint64_t)a0;
  magic_mem[2] = (uint64_t)a1;
  magic_mem[3] = (uint64_t)a2;
  magic_mem[4] = 0;
  magic_mem[5] = 0;
  magic_mem[6] = 0;
  magic_mem[7] = 0;

  htif_fence();
  tohost = (uintptr_t)magic_mem;
  while (fromhost == 0) {
  }
  fromhost = 0;
  htif_fence();

  return (long)magic_mem[0];
}

static size_t align_up(size_t value, size_t alignment)
{
  if (alignment == 0) {
    return value;
  }
  return (value + alignment - 1) & ~(alignment - 1);
}

void htif_exit(int code)
{
  tohost = ((uint64_t)code << 1) | 1;
  while (1) {
  }
}

size_t htif_write_fd(int fd, const void* buf, size_t len)
{
  return (size_t)htif_proxy_syscall(SYS_write, (uintptr_t)fd, (uintptr_t)buf, len);
}

size_t htif_write(const void* buf, size_t len)
{
  return htif_write_fd(HTIF_STDOUT_FD, buf, len);
}

static void buffer_putc(char ch, char* out, size_t n, size_t* pos)
{
  if (*pos + 1 < n) {
    out[*pos] = ch;
  }
  (*pos)++;
}

static void buffer_repeat(char ch, int count, char* out, size_t n, size_t* pos)
{
  while (count-- > 0) {
    buffer_putc(ch, out, n, pos);
  }
}

static int u64_digits(unsigned long long value, unsigned base)
{
  int digits = 1;
  while (value >= base) {
    value /= base;
    digits++;
  }
  return digits;
}

static void buffer_uint(unsigned long long value, unsigned base, int min_digits,
                        char* out, size_t n, size_t* pos)
{
  char buf[32];
  int idx = 0;

  do {
    unsigned digit = (unsigned)(value % base);
    buf[idx++] = (char)(digit < 10 ? '0' + digit : 'a' + digit - 10);
    value /= base;
  } while (value != 0);

  while (idx < min_digits) {
    buf[idx++] = '0';
  }

  while (idx-- > 0) {
    buffer_putc(buf[idx], out, n, pos);
  }
}

static void format_fixed(double value, int precision, int width, char padc,
                         char* out, size_t n, size_t* pos)
{
  unsigned long long scale = 1;
  unsigned long long rounded;
  unsigned long long int_part;
  unsigned long long frac_part;
  int int_digits;
  int total_width;
  bool negative = false;

  if (precision < 0) {
    precision = 6;
  }
  if (value < 0) {
    negative = true;
    value = -value;
  }
  for (int i = 0; i < precision; ++i) {
    scale *= 10ULL;
  }

  rounded = (unsigned long long)(value * (double)scale + 0.5);
  int_part = rounded / scale;
  frac_part = rounded % scale;
  int_digits = u64_digits(int_part, 10);
  total_width = int_digits + (precision > 0 ? precision + 1 : 0) + (negative ? 1 : 0);

  if (width > total_width && padc != '0') {
    buffer_repeat(' ', width - total_width, out, n, pos);
  }
  if (negative) {
    buffer_putc('-', out, n, pos);
  }
  if (width > total_width && padc == '0') {
    buffer_repeat('0', width - total_width, out, n, pos);
  }
  buffer_uint(int_part, 10, 1, out, n, pos);
  if (precision > 0) {
    buffer_putc('.', out, n, pos);
    buffer_uint(frac_part, 10, precision, out, n, pos);
  }
}

int putchar(int ch)
{
  char c = (char)ch;
  htif_write(&c, 1);
  return ch;
}

int puts(const char* s)
{
  static const char newline = '\n';
  size_t len = strlen(s);
  htif_write(s, len);
  htif_write(&newline, 1);
  return (int)(len + 1);
}

static int vfprintf_impl(FILE* stream, const char* fmt, va_list ap)
{
  char out[256];
  int len = vsnprintf(out, sizeof(out), fmt, ap);
  if (len < 0) {
    return len;
  }

  size_t write_len = (size_t)len;
  if (write_len >= sizeof(out)) {
    write_len = sizeof(out) - 1;
  }
  htif_write_fd(stream == stderr ? HTIF_STDERR_FD : HTIF_STDOUT_FD, out, write_len);
  return len;
}

int printf(const char* fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  int len = vfprintf_impl(stdout, fmt, ap);
  va_end(ap);
  return len;
}

int fprintf(FILE* stream, const char* fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  int len = vfprintf_impl(stream, fmt, ap);
  va_end(ap);
  return len;
}

void perror(const char* s)
{
  if (s && *s) {
    fprintf(stderr, "%s\n", s);
  }
}

int vsnprintf(char* out, size_t n, const char* fmt, va_list ap)
{
  size_t pos = 0;

  for (; *fmt; ++fmt) {
    int width = 0;
    int precision = -1;
    int lflag = 0;
    char padc = ' ';
    bool left_align = false;

    if (*fmt != '%') {
      buffer_putc(*fmt, out, n, &pos);
      continue;
    }

    ++fmt;
    while (*fmt == '-' || *fmt == '0') {
      if (*fmt == '-') {
        left_align = true;
        padc = ' ';
      } else if (!left_align) {
        padc = '0';
      }
      ++fmt;
    }
    while (*fmt >= '0' && *fmt <= '9') {
      width = width * 10 + (*fmt - '0');
      ++fmt;
    }
    if (*fmt == '.') {
      precision = 0;
      ++fmt;
      while (*fmt >= '0' && *fmt <= '9') {
        precision = precision * 10 + (*fmt - '0');
        ++fmt;
      }
    }
    while (*fmt == 'l') {
      lflag++;
      ++fmt;
    }

    switch (*fmt) {
      case 'c':
        buffer_putc((char)va_arg(ap, int), out, n, &pos);
        break;
      case 'd':
      case 'u':
      {
        unsigned long long num;
        bool negative = false;

        if (*fmt == 'd') {
          long long signed_num;
          if (lflag >= 2) {
            signed_num = va_arg(ap, long long);
          } else if (lflag == 1) {
            signed_num = va_arg(ap, long);
          } else {
            signed_num = va_arg(ap, int);
          }
          if (signed_num < 0) {
            negative = true;
            num = (unsigned long long)(-signed_num);
          } else {
            num = (unsigned long long)signed_num;
          }
        } else {
          if (lflag >= 2) {
            num = va_arg(ap, unsigned long long);
          } else if (lflag == 1) {
            num = va_arg(ap, unsigned long);
          } else {
            num = va_arg(ap, unsigned int);
          }
        }

        int digits = u64_digits(num, 10);
        int total_width = digits + (negative ? 1 : 0);
        if (width > total_width && padc != '0') {
          buffer_repeat(' ', width - total_width, out, n, &pos);
        }
        if (negative) {
          buffer_putc('-', out, n, &pos);
        }
        if (width > total_width && padc == '0') {
          buffer_repeat('0', width - total_width, out, n, &pos);
        }
        buffer_uint(num, 10, 1, out, n, &pos);
        break;
      }
      case 'x':
      case 'p':
      {
        unsigned long long num;
        int digits;

        if (*fmt == 'p') {
          num = (uintptr_t)va_arg(ap, void*);
          buffer_putc('0', out, n, &pos);
          buffer_putc('x', out, n, &pos);
          digits = 2 * (int)sizeof(uintptr_t);
        } else if (lflag >= 2) {
          num = va_arg(ap, unsigned long long);
          digits = precision >= 0 ? precision : 1;
        } else if (lflag == 1) {
          num = va_arg(ap, unsigned long);
          digits = precision >= 0 ? precision : 1;
        } else {
          num = va_arg(ap, unsigned int);
          digits = precision >= 0 ? precision : 1;
        }

        if (*fmt != 'p') {
          int actual = u64_digits(num, 16);
          int used = digits > actual ? digits : actual;
          if (width > used && padc != '0') {
            buffer_repeat(' ', width - used, out, n, &pos);
          }
          if (width > used && padc == '0') {
            buffer_repeat('0', width - used, out, n, &pos);
          }
          digits = used;
        }

        buffer_uint(num, 16, digits, out, n, &pos);
        break;
      }
      case 's':
      {
        const char* s = va_arg(ap, const char*);
        if (!s) {
          s = "(null)";
        }
        int slen = (int)strlen(s);
        if (precision >= 0 && slen > precision) {
          slen = precision;
        }
        if (width > slen && !left_align) {
          buffer_repeat(' ', width - slen, out, n, &pos);
        }
        for (int i = 0; i < slen; ++i) {
          buffer_putc(*s, out, n, &pos);
          ++s;
        }
        if (width > slen && left_align) {
          buffer_repeat(' ', width - slen, out, n, &pos);
        }
        break;
      }
      case 'f':
      {
        double value = va_arg(ap, double);
        format_fixed(value, precision, width, padc, out, n, &pos);
        break;
      }
      case '%':
        buffer_putc('%', out, n, &pos);
        break;
      default:
        buffer_putc('%', out, n, &pos);
        buffer_putc(*fmt, out, n, &pos);
        break;
    }
  }

  if (pos < n) {
    out[pos] = 0;
  } else if (n) {
    out[n - 1] = 0;
  }
  return (int)pos;
}

int snprintf(char* out, size_t n, const char* fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  int rc = vsnprintf(out, n, fmt, ap);
  va_end(ap);
  return rc;
}

static alloc_header_t* ptr_to_header(void* ptr)
{
  return ptr ? &((alloc_header_t*)ptr)[-1] : NULL;
}

void* malloc(size_t size)
{
  size_t off = align_up(baremetal_heap_off, 16);
  size_t next = off + sizeof(alloc_header_t) + size;
  alloc_header_t* hdr;

  if (next > sizeof(baremetal_heap)) {
    return NULL;
  }

  hdr = (alloc_header_t*)&baremetal_heap[off];
  hdr->size = size;
  baremetal_heap_off = next;
  return hdr + 1;
}

void free(void* ptr)
{
  (void)ptr;
}

int posix_memalign(void** memptr, size_t alignment, size_t size)
{
  size_t off;
  size_t hdr_off;
  size_t next;
  alloc_header_t* hdr;

  if (!memptr || alignment < sizeof(void*) || (alignment & (alignment - 1)) != 0) {
    return 22;
  }

  off = baremetal_heap_off + sizeof(alloc_header_t);
  off = align_up(off, alignment);
  hdr_off = off - sizeof(alloc_header_t);
  next = off + size;
  if (next > sizeof(baremetal_heap)) {
    return 12;
  }

  hdr = (alloc_header_t*)&baremetal_heap[hdr_off];
  hdr->size = size;
  baremetal_heap_off = next;
  *memptr = &baremetal_heap[off];
  return 0;
}

void* calloc(size_t n, size_t size)
{
  size_t total = n * size;
  void *ptr = malloc(total);
  if (ptr) {
    memset(ptr, 0, total);
  }
  return ptr;
}

void* realloc(void* ptr, size_t size)
{
  alloc_header_t* hdr;
  void *next;
  size_t copy_len;

  if (!ptr) {
    return malloc(size);
  }
  if (size == 0) {
    free(ptr);
    return NULL;
  }

  hdr = ptr_to_header(ptr);
  next = malloc(size);
  if (!next) {
    return NULL;
  }
  copy_len = hdr->size < size ? hdr->size : size;
  memcpy(next, ptr, copy_len);
  return next;
}

void srand(unsigned seed)
{
  rand_state = seed ? seed : 1;
}

int rand(void)
{
  rand_state = rand_state * 1103515245u + 12345u;
  return (int)((rand_state >> 16) & 0x7fff);
}

static void swap_bytes(unsigned char* lhs, unsigned char* rhs, size_t size)
{
  while (size--) {
    unsigned char tmp = *lhs;
    *lhs++ = *rhs;
    *rhs++ = tmp;
  }
}

void qsort(void* base, size_t nmemb, size_t size,
           int (*compar)(const void*, const void*))
{
  unsigned char* arr = (unsigned char*)base;
  for (size_t i = 1; i < nmemb; ++i) {
    for (size_t j = i; j > 0; --j) {
      unsigned char* lhs = arr + (j - 1) * size;
      unsigned char* rhs = arr + j * size;
      if (compar(lhs, rhs) <= 0) {
        break;
      }
      swap_bytes(lhs, rhs, size);
    }
  }
}

FILE* fopen(const char* path, const char* mode)
{
  (void)path;
  (void)mode;
  return NULL;
}

int fclose(FILE* stream)
{
  (void)stream;
  return 0;
}

int fflush(FILE* stream)
{
  (void)stream;
  return 0;
}

int mkdir(const char* path, mode_t mode)
{
  (void)path;
  (void)mode;
  return 0;
}

void* memcpy(void* dest, const void* src, size_t len)
{
  unsigned char* d = (unsigned char*)dest;
  const unsigned char* s = (const unsigned char*)src;
  while (len--) {
    *d++ = *s++;
  }
  return dest;
}

void* memset(void* dest, int value, size_t len)
{
  unsigned char* d = (unsigned char*)dest;
  while (len--) {
    *d++ = (unsigned char)value;
  }
  return dest;
}

size_t strlen(const char* s)
{
  const char* p = s;
  while (*p) {
    ++p;
  }
  return (size_t)(p - s);
}

int strcmp(const char* lhs, const char* rhs)
{
  while (*lhs && *lhs == *rhs) {
    ++lhs;
    ++rhs;
  }
  return (unsigned char)*lhs - (unsigned char)*rhs;
}

char* strcpy(char* dest, const char* src)
{
  char* out = dest;
  while ((*dest++ = *src++) != '\0') {
  }
  return out;
}
