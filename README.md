创建Tbase用户
# 创建数据存储目录（所有集群节点需统一路径）
mkdir -p /opt/xiaosongyuan
# 创建专用用户并指定主目录
useradd -d /opt/xiaosongyuan -m tbase  
# 设置目录权限
chown -R tbase:tbase /opt/xiaosongyuan
获取源码master分支（0451d9d9e610297c86c091b405692c972492e1e1）
sudo su - tbase
cd /opt/xiaosongyuan
git clone https://github.com/Tencent/TBase
修改源码
1. 修改/src/gtm/proxy/gtm_proxy_opt.c
diff --git a/src/gtm/proxy/gtm_proxy_opt.c b/src/gtm/proxy/gtm_proxy_opt.c
index d54fe67..fc5b033 100644
--- a/src/gtm/proxy/gtm_proxy_opt.c
+++ b/src/gtm/proxy/gtm_proxy_opt.c
@@ -75,7 +75,7 @@ Server_Message_Level_Options();
  * GTM option variables that are exported from this module
  */
 char       *data_directory;
-char       *GTMConfigFileName;
+//char       *GTMConfigFileName;
2. 修改src/include/port/atomics.h
@@ -74,6 +74,8 @@
#include "port/atomics/arch-ppc.h"
#elif defined(__hppa) || defined(__hppa__)
#include "port/atomics/arch-hppa.h"
+#elif defined(__riscv) && defined(__riscv_xlen) && (__riscv_xlen == 64)
+#include "port/atomics/arch-rv64.h"
#endif

/*
3. 新增文件src/include/port/atomics/arch-rv64.h
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
4. 修改src/include/storage/s_lock.h
@@ -363,6 +363,36 @@ tas(volatile slock_t *lock)

#endif     /* __s390__ || __s390x__ */

+#if defined(__riscv) && defined(__riscv_xlen) && (__riscv_xlen == 64)
+#ifdef HAVE_GCC__SYNC_INT32_TAS
+#define HAS_TEST_AND_SET
+
+typedef int slock_t;
+
+#define TAS(lock) tas(lock)
+
+static __inline__ int
+tas(volatile slock_t *lock)
+{
+    /* 利用 gcc 内置的原子测试并设置函数 */
+    return __sync_lock_test_and_set(lock, 1);
+}
+
+/* 当检测到锁已经被占用时，可以选择先做个非锁定测试 */
+#define TAS_SPIN(lock)    (*(lock) ? 1 : TAS(lock))
+
+#define S_UNLOCK(lock) __sync_lock_release(lock)
+
+#define SPIN_DELAY() spin_delay()
+
+static __inline__ void
+spin_delay(void)
+{
+    /* 对 RISC-V 使用简单的 nops 延迟 */
+   __asm__ __volatile__("nop" ::: "memory");
+}
+#endif  /* HAVE_GCC__SYNC_INT32_TAS */
+#endif  /* defined(__riscv) && (__riscv_xlen == 64) */

#if defined(__sparc__)        /* Sparc */
/*
5. 修改src/include/pgxc/pgxcnode.h
@@ -301,7 +301,7 @@ int pgxc_get_coordinator_proc_pid(void);
void pgxc_set_coordinator_proc_vxid(TransactionId proc_vxid);
TransactionId pgxc_get_coordinator_proc_vxid(void);
PGXCNodeHandle* find_ddl_leader_cn(void);
-inline bool  is_ddl_leader_cn(char *leader_cn);
+bool  is_ddl_leader_cn(char *leader_cn);
void CheckInvalidateRemoteHandles(void);
extern int pgxc_node_send_sessionid(PGXCNodeHandle * handle);
extern void SerializeSessionId(Size maxsize, char *start_address);
6. 修改/src/contrib/pgxc_ctl/variables.c和/src/contrib/pgxc_ctl/variables.h
diff --git a/contrib/pgxc_ctl/variables.c b/contrib/pgxc_ctl/variables.c
index f8bd891..121f62b 100644
--- a/contrib/pgxc_ctl/variables.c
+++ b/contrib/pgxc_ctl/variables.c
@@ -17,6 +17,7 @@
 
 pgxc_ctl_var *var_head = NULL;
 pgxc_ctl_var *var_tail = NULL;
+pgxc_var_hash var_hash[NUM_HASH_BUCKET];
 
 static void clear_var(pgxc_ctl_var *var);
 /*
diff --git a/contrib/pgxc_ctl/variables.h b/contrib/pgxc_ctl/variables.h
index 644b3d0..cef8603 100644
--- a/contrib/pgxc_ctl/variables.h
+++ b/contrib/pgxc_ctl/variables.h
@@ -44,7 +44,7 @@ typedef struct pgxc_var_hash {
 } pgxc_var_hash;
 
 
-pgxc_var_hash var_hash[NUM_HASH_BUCKET];
+extern pgxc_var_hash var_hash[NUM_HASH_BUCKET];
 
 void init_var_hash(void);
 void add_var_hash(pgxc_ctl_var *var);

编译安装 OpenSSL 1.1.1s
wget https://www.openssl.org/source/openssl-1.1.1s.tar.gz
tar -xzvf openssl-1.1.1s.tar.gz
cd openssl-1.1.1s

# 编译安装到独立目录（避免污染系统库）
./config --prefix=/opt/xiaosongyuan/install/openssl-1.1.1 --openssldir=/opt/xiaosongyuan/install/openssl-1.1.1/ssl
make -j$(nproc)
sudo make install
配置编译时OpenSSL
# 设置头文件和库路径
export CFLAGS="-I/opt/xiaosongyuan/install/openssl-1.1.1/include -g"
export LDFLAGS="-L/opt/xiaosongyuan/install/openssl-1.1.1/lib -Wl,-rpath=/opt/xiaosongyuan/install/openssl-1.1.1/lib"

# 确保 pkg-config 能找到自定义 OpenSSL
export PKG_CONFIG_PATH="/opt/xiaosongyuan/install/openssl-1.1.1/lib/pkgconfig"

# 验证变量是否生效
echo $CFLAGS      # 应显示 -I/opt/xiaosongyuan/install/openssl-1.1.1/include -g
echo $LDFLAGS     # 应显示 -L/opt/xiaosongyuan/install/openssl-1.1.1/lib -Wl,-rpath=...
echo $PKG_CONFIG_PATH  # 应显示 /opt/xiaosongyuan/install/openssl-1.1.1/lib/pkgconfig
源码编译
# 进入源码目录
cd TBase

# 清理旧编译文件（若存在）
rm -rf /data/tbase/install/tbase_bin_v2.0

# 赋予配置脚本执行权限
chmod +x configure*

# 执行配置命令（关键参数说明）
./configure \
  --prefix=/opt/xiaosongyuan/install/tbase_bin_v2.0 \
  --enable-user-switch \
  --disable-strong-random \
  --with-openssl \
  --with-includes=/opt/xiaosongyuan/install/openssl-1.1.1/include \
  --with-libraries=/opt/xiaosongyuan/install/openssl-1.1.1/lib \
  --with-ossp-uuid \
  CFLAGS="$CFLAGS" \
  LDFLAGS="$LDFLAGS"

# 编译与安装
make clean       # 清理旧编译结果
rm -rf config.cache config.status# 清理旧编译结果
make -sj $(nproc) > build.log 2>&1 # 并行编译（-j后接CPU核心数，如4核则用-j4）
grep -i error build.log | head -n 20
make install     # 安装到指定目录

# 编译contrib扩展
chmod +x contrib/pgxc_ctl/make_signature
cd contrib
make -sj $(nproc)
make install
