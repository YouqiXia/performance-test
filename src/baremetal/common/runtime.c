#include "htif_stdio.h"

#include <stdint.h>

int main(void);

void __attribute__((weak)) thread_entry(int hartid, int n_harts)
{
  (void)n_harts;
  while (hartid != 0) {
  }
}

uintptr_t __attribute__((weak)) handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32])
{
  (void)regs;
  printf("trap: mcause=0x%lx mepc=0x%lx\n", (unsigned long)cause, (unsigned long)epc);
  htif_exit(128);
}

void _init(int hartid, int n_harts)
{
  thread_entry(hartid, n_harts);
  htif_exit(main());
}
