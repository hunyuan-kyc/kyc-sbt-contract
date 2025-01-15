user requestKyc 之后不需要 admin approve 或者 reject
这是原先的状态
enum KycStatus { NONE, PENDING, APPROVED, REJECTED, REVOKED }
应该只保留 
enum KycStatus { NONE, APPROVED, REVOKED }
原先有user admin owner 三种角色， 不需要 admin 角色

REVOKED 之后 继续保留它的 ens 但是可以恢复成 APPROVED 状态

REVOKED 可以是 user 本人 或者是 owner 
恢复只能是 owner（但是为了测试 需要临时加一个 user 本人也可以恢复的功能）


KycInfos 应该去增加一个方法 getKycInfos 查询状态

请修改相关合约 和 测试脚本
