set foreign_key_checks = 0;

-- ----------------------------------------------------------------------------------------------------------------
-- 微信订单
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS erp_wx_vendi_bil;
CREATE TABLE `erp_wx_vendi_bil` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '销售订单编号,erp_vendi_bil.id',
  `pay_route` varchar(50) NOT NULL COMMENT '支付方式',
  `pay_state` varchar(50) NOT NULL COMMENT '支付状态，PAYING:支付中，PAID:已支付，UNPAID:支付失败，CANCELED:取消支付，EXPIRED:已超时未支付',
  PRIMARY KEY (`id`),
  KEY `erp_wx_vendi_bil_pay_route_idx` (`pay_route`),
  KEY `erp_wx_vendi_bil_pay_state_idx` (`pay_state`),
  CONSTRAINT `fk_erp_wx_vendi_bil_erp_vendi_bil_id` FOREIGN KEY (`erp_vendi_bil_id`) 
		REFERENCES `erp_vendi_bil` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='微信订单'
;