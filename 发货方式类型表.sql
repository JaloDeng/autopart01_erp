-- ----------------------------------------------------------------------------------------------------------------
-- 发货方式类型表
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS erp_delivery_type;
CREATE TABLE `erp_delivery_type` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billType` int NOT NULL COMMENT '单据类型，1：销售，2：采购',
  `type` varchar(100) NOT NULL COMMENT '类型',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `ers_delivery_type_type_idx` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='发货方式类型表'
;