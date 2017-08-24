SET FOREIGN_KEY_CHECKS =0;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	供应商支付方式
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_supplier_payment`;
CREATE TABLE `erp_supplier_payment` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `supplierId` bigint(20) NOT NULL COMMENT '供应商ID',
  `erp_payment_type_id` int(20) NOT NULL COMMENT '支付方式ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `supplierId_paymentId_UNIQUE` (`supplierId`,`erp_payment_type_id`) USING BTREE,
  KEY `supplier_payment_erp_payment_type_id_idx` (`erp_payment_type_id`) USING BTREE,
	CONSTRAINT `fk_erp_supplier_payment_payment_type_id` FOREIGN KEY (`erp_payment_type_id`) 
		REFERENCES `erp_payment_type` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='供应商支付方式'
;