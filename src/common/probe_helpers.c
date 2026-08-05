#include "probe_helpers.h"
#include "arch_params.h"
#include <stdio.h>

void probe_begin(probe_ctx_t *p, const char *case_name,
                 const char *x_label, const char *y_unit)
{
    p->case_name = case_name;
    p->emitted = 0;

    printf("##PROBE_JSON_BEGIN##\n");
    printf("{\n");
    printf("  \"case\": \"%s\",\n", case_name);
    printf("  \"arch\": \"%s\",\n", ARCH_NAME);
    printf("  \"x_label\": \"%s\",\n", x_label);
    printf("  \"y_unit\": \"%s\",\n", y_unit);
    printf("  \"points\": [\n");
}

void probe_emit_point(probe_ctx_t *p,
                      long x,
                      uint64_t cycles,
                      uint64_t instret,
                      uint64_t total_iters,
                      uint64_t instr_per_iter)
{
    double cyc_iter = total_iters ? (double)cycles / total_iters : 0.0;
    double ipc = cycles ? (double)instret / cycles : 0.0;
    uint64_t total_insn_expected = total_iters * instr_per_iter;

    if (p->emitted)
        printf(",\n");

    printf("    {\"x\": %ld, \"cycles\": %lu, \"instret\": %lu, "
           "\"total_iters\": %lu, \"instr_per_iter\": %lu, "
           "\"total_insn_expected\": %lu, "
           "\"cycles_per_iter\": %.4f, \"ipc\": %.6f}",
           x, cycles, instret, total_iters, instr_per_iter,
           total_insn_expected, cyc_iter, ipc);

    p->emitted++;
}

void probe_end(probe_ctx_t *p)
{
    printf("\n  ]\n");
    printf("}\n");
    printf("##PROBE_JSON_END##\n");
    (void)p;
}
