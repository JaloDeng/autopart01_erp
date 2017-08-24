set foreign_key_checks = 0;

-- ----------------------------------------------------------------------------------------------------------------
-- 微信支付表
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS erp_wx_vendi_bil_pay;
CREATE TABLE `erp_wx_vendi_bil_pay` (
  `id` bigint(20) NOT NULL COMMENT '自增编码',
  `priceSumSell` BIGINT DEFAULT NULL COMMENT '销售单金额，单位：分',
  `settlement_priceSumSell` BIGINT DEFAULT NULL COMMENT '应结订单金额，应结订单金额=订单金额-非充值代金券金额，应结订单金额<=订单金额',
  `time_start` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '交易起始时间',
  `time_expire` datetime DEFAULT NULL COMMENT '交易结束时间',
  `time_end` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '支付完成时间',
  `goods_tag` varchar(32) DEFAULT NULL COMMENT '商品标记，使用代金券或立减优惠功能时需要的参数',
  `out_trade_no` varchar(32) DEFAULT NULL COMMENT '商户订单号',
  `trade_type` varchar(16) DEFAULT NULL COMMENT '交易类型：JSAPI，NATIVE，APP等',
  `prepay_id` varchar(64) DEFAULT NULL COMMENT '预支付交易会话标识,wx201410272009395522657a690389285100,微信生成的预支付会话标识,用于后续接口调用中使用，该值有效期为2小时',
  `code_url` varchar(64) DEFAULT NULL COMMENT '二维码链接,URl：weixin：//wxpay/s/An4baqw	trade_type为NATIVE时有返回，用于生成二维码，展示给用户进行扫码支付',
  `spbill_create_ip` varchar(16) DEFAULT NULL COMMENT '终端IP,123.12.12.123	APP和网页支付提交用户端ip，Native支付填调用微信支付API的机器IP。',
  `goodsId` bigint(20) DEFAULT NULL COMMENT '商品ID，trade_type=NATIVE时（即扫码支付），此参数必传',
  `openId` varchar(128) DEFAULT NULL COMMENT '用户的标识，对当前公众号唯一',
  `payOpenId` varchar(128) DEFAULT NULL COMMENT '付款用户的标识，对当前公众号唯一',
  `bank_type` varchar(16) DEFAULT NULL COMMENT '付款银行：银行类型，采用字符串类型的银行标识',
  `cash_fee` BIGINT DEFAULT NULL COMMENT '现金支付金额，现金支付金额订单现金支付金额',
  `coupon_fee` BIGINT DEFAULT NULL COMMENT '总代金券金额，代金券金额<=订单金额，订单金额-代金券金额=现金支付金额',
  `coupon_count` int DEFAULT NULL COMMENT '代金券使用数量',
  `transaction_id` varchar(32) DEFAULT NULL COMMENT '微信支付订单号',
  PRIMARY KEY (`id`),
  KEY `erp_wx_vendi_bil_pay_trade_type_idx` (`trade_type`),
  KEY `erp_wx_vendi_bil_pay_transaction_id_idx` (`transaction_id`),
	CONSTRAINT `fk_erp_wx_vendi_bil_pay_id` FOREIGN KEY (`id`) 
		REFERENCES `erp_wx_vendi_bil` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='微信支付表'
;