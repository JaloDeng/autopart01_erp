-- ----------------------------------------------------------------------------------------------------------------
-- 盘点商品表
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS ers_inventory_goods;
CREATE TABLE `ers_inventory_goods` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `ers_inventory_type_id` int NOT NULL COMMENT '盘点类型',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '审核状态 -1:未提交或审核退回 0:提交待审 1:已审核',
  `goodsId` bigint(20) DEFAULT NULL COMMENT '要盘点的商品',
  `ers_roomattr_id` bigint(20) DEFAULT NULL COMMENT '要盘点的仓库',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '更新用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '更新员工ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `createdBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工用户名',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工姓名',
  `lastModifiedBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工用户名',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工姓名',
  `checkEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核人',
  `code` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '盘点任务单号',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `ers_inventory_task_ers_inventory_type_id_idx` (`ers_inventory_type_id`),
  KEY `ers_inventory_task_isCheck_idx` (`isCheck`),
  KEY `ers_inventory_task_goodsId_idx` (`goodsId`),
  KEY `ers_inventory_task_ers_roomattr_id_idx` (`ers_roomattr_id`),
  KEY `ers_inventory_task_code_idx` (`code`),
  CONSTRAINT `fk_ers_inventory_task_ers_inventory_type_id` FOREIGN KEY (`ers_inventory_type_id`) 
		REFERENCES `ers_inventory_type` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='盘点任务表'
;