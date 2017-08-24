-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 个人预约服务
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_reservation`;
CREATE TABLE `erp_reservation` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `remindBeforeOne` bit(1) DEFAULT NULL COMMENT '提前1天提醒',
  `remindBeforeTwo` bit(1) DEFAULT NULL COMMENT '提前2天提醒',
  `remindBeforeThree` bit(1) DEFAULT NULL COMMENT '提前3天提醒',
  `customerId` bigint(20) NOT NULL COMMENT '客户ID',
  `reserveDate` datetime DEFAULT NULL COMMENT '预约时间',
  `reserveItems` longtext DEFAULT NULL COMMENT '预约项目',
  `address` varchar(1000) DEFAULT NULL COMMENT '地址',
  `memo` varchar(1000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erp_reservation_customerId_idx` (`customerId`) USING BTREE,
  KEY `erp_reservation_reserveDate_idx` (`reserveDate`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='个人预约服务';