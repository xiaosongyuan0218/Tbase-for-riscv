/*-------------------------------------------------------------------------
 *
 * arch-rv64.h
 *      针对 RISC-V 64位架构（RV64）的原子操作支持
 *
 * Portions Copyright (c) 2023, PostgreSQL Global Development Group
 *
 * 说明：
 *
 * 本文件提供针对 RISC-V 64位平台的原子操作实现细节。
 * 如果编译器未定义 __riscv，或者 __riscv_xlen 未定义或不等于64，
 * 或者缺少原子扩展支持（例如 __riscv_atomic 未定义），
 * 则禁用64位原子操作。
 *
 *-------------------------------------------------------------------------
 */

/* 本文件故意不使用包含保护，应该仅通过 atomics.h 进行包含 */
#ifndef INSIDE_ATOMICS_H
#error "应该通过 atomics.h 进行包含"
#endif

/*
 * 针对 RISC-V 64位架构：
 * 如果编译器未定义 __riscv，或者 __riscv_xlen 未定义或不等于64，
 * 或者未定义 __riscv_atomic（表示缺少原子扩展支持），则禁用64位原子操作。
 */
#if !defined(__riscv) || !defined(__riscv_xlen) || (__riscv_xlen != 64) || !defined(__riscv_atomic)
#define PG_DISABLE_64_BIT_ATOMICS
#endif  /* __riscv, __riscv_xlen 或 __riscv_atomic 条件判断 */
