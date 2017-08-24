DROP TABLE IF EXISTS `erp_payment_type`;
CREATE TABLE `erp_payment_type` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
	`type` VARCHAR(100) NOT NULL COMMENT '支付方式',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_payment_type_type_UNIQUE` (`type`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付方式'
;