-- ----------------------------------------------------------------------------------------------------------------
-- 盘点类型表
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS ers_inventory_type;
CREATE TABLE `ers_inventory_type` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `type` varchar(100) NOT NULL COMMENT '盘点类型',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `ers_inventory_type_type_idx` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='盘点类型表'
;