-- ----------------------------------------------------------------------------------------------------------------
-- 微信礼品券
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS erp_wx_coupon;
CREATE TABLE `erp_wx_coupon` (
  `id` varchar(32) NOT NULL COMMENT '自增编码',
  `fee` bigint DEFAULT 0 COMMENT '费用',
  `payment_id` bigint NOT NULL COMMENT '微信支付表ID',
  `type` varchar(32) NOT NULL COMMENT '类型',
  PRIMARY KEY (`id`),
  KEY `erp_wx_coupon_type_idx` (`type`),
	CONSTRAINT `fk_erp_wx_coupon_payment_id` FOREIGN KEY (`payment_id`) 
		REFERENCES `erp_wx_vendi_bil_pay` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='微信礼品券'
;