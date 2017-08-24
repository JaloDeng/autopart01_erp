-- ----------------------------
--  Table structure for `erp_vendi_detail_shelfQty`
-- ----------------------------
DROP TABLE IF EXISTS `erp_vendi_detail_shelfQty`;
CREATE TABLE `erp_vendi_detail_shelfQty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_detail_id` bigint(20) NOT NULL COMMENT '销售明细ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `ers_shelfattr_id` bigint(20) DEFAULT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`snCode` VARCHAR(255) DEFAULT NULL COMMENT '包裹扫描码',
  PRIMARY KEY (`id`),
	KEY `erp_vendi_detail_shelfQty_erp_vendi_detail_id_idx` (`erp_vendi_detail_id`),
	KEY `erp_vendi_detail_shelfQty_goodsId_idx` (`goodsId`),
	KEY `erp_vendi_detail_shelfQty_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
	KEY `erp_vendi_detail_shelfQty_ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `erp_vendi_detail_shelfQty_snCode_idx` (`snCode`),
	CONSTRAINT `erp_vendi_detail_shelfQty_goodsId` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `erp_vendi_detail_shelfQty_erp_vendi_detail_id` FOREIGN KEY (`erp_vendi_detail_id`) REFERENCES `erp_vendi_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `erp_vendi_detail_shelfQty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `erp_vendi_detail_shelfQty_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='包裹销售出仓逐个条码＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;

-- ----------------------------
--  Table structure for `erp_purch_detail_shelfQty`
-- ----------------------------
DROP TABLE IF EXISTS `erp_purch_detail_shelfQty`;
CREATE TABLE `erp_purch_detail_shelfQty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_detail_id` bigint(20) NOT NULL COMMENT '采购单明细ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `ers_shelfattr_id` bigint(20) DEFAULT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`snCode` VARCHAR(255) DEFAULT NULL COMMENT '包裹扫描码',
  PRIMARY KEY (`id`),
	KEY `erp_purch_detail_shelfQty_erp_purch_detail_id_idx` (`erp_purch_detail_id`),
	KEY `erp_purch_detail_shelfQty_goodsId_idx` (`goodsId`),
	KEY `erp_purch_detail_shelfQty_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
	KEY `erp_purch_detail_shelfQty_ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `erp_purch_detail_shelfQty_snCode_idx` (`snCode`),
	CONSTRAINT `fk_erp_purch_detail_shelfQty_goodsId` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_purch_detail_shelfQty_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_detail_shelfQty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_detail_shelfQty_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='包裹采购进仓逐个条码＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;

-- ----------------------------
--  Table structure for `erp_goods_shelfQty`
-- ----------------------------
DROP TABLE IF EXISTS `erp_goods_shelfQty`;
CREATE TABLE `erp_goods_shelfQty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`snCode` VARCHAR(255) DEFAULT NULL COMMENT '包裹扫描码',
  PRIMARY KEY (`id`),
	KEY `erp_goods_shelfQty_goodsId_idx` (`goodsId`),
	KEY `erp_goods_shelfQty_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
	KEY `erp_goods_shelfQty_ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `erp_goods_shelfQty_snCode_idx` (`snCode`),
	CONSTRAINT `fk_erp_goods_shelfQty_goodsId` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_goods_shelfQty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_goods_shelfQty_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='包裹库存逐个条码＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;

-- ----------------------------
--  Table structure for `erp_purch_rejt_detail_shelfQty`
-- ----------------------------
DROP TABLE IF EXISTS `erp_purch_rejt_detail_shelfQty`;
CREATE TABLE `erp_purch_rejt_detail_shelfQty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_rejt_detail_id` bigint(20) NOT NULL COMMENT '采购退货明细ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`snCode` VARCHAR(255) DEFAULT NULL COMMENT '包裹扫描码',
  PRIMARY KEY (`id`),
	KEY `erp_purch_rejt_detail_shelfQty_erp_purch_rejt_bil_id_idx` (`erp_purch_rejt_bil_id`),
	KEY `erp_purch_rejt_detail_shelfQty_goodsId_idx` (`goodsId`),
	KEY `erp_purch_rejt_detail_shelfQty_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
	KEY `erp_purch_rejt_detail_shelfQty_ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `erp_purch_rejt_detail_shelfQty_snCode_idx` (`snCode`),
	CONSTRAINT `fk_erp_purch_rejt_detail_shelfQty_goodsId` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_purch_rejt_detail_shelfQty_erp_purch_rejt_detail_id` FOREIGN KEY (`erp_purch_rejt_detail_id`) REFERENCES `erp_purch_rejt_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_rejt_detail_shelfQty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_rejt_detail_shelfQty_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='包裹采购退货出仓逐个条码＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;

-- ----------------------------
--  Table structure for `erp_vendi_rejt_detail_shelfQty`
-- ----------------------------
DROP TABLE IF EXISTS `erp_vendi_rejt_detail_shelfQty`;
CREATE TABLE `erp_vendi_rejt_detail_shelfQty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_rejt_detail_id` bigint(20) NOT NULL COMMENT '销售退货单ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`snCode` VARCHAR(255) DEFAULT NULL COMMENT '包裹扫描码',
  PRIMARY KEY (`id`),
	KEY `erp_vendi_rejt_detail_shelfQty_erp_vendi_rejt_detail_id_idx` (`erp_vendi_rejt_detail_id`),
	KEY `erp_vendi_rejt_detail_shelfQty_goodsId_idx` (`goodsId`),
	KEY `erp_vendi_rejt_detail_shelfQty_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
	KEY `erp_vendi_rejt_detail_shelfQty_ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `erp_vendi_rejt_detail_shelfQty_snCode_idx` (`snCode`),
	CONSTRAINT `fk_erp_vendi_rejt_detail_shelfQty_goodsId` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_vendi_rejt_detail_shelfQty_erp_vendi_rejt_detail_id` FOREIGN KEY (`erp_vendi_rejt_detail_id`) REFERENCES `erp_vendi_rejt_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_vendi_rejt_detail_shelfQty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_vendi_rejt_detail_shelfQty_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='包裹销售退货进仓逐个条码＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;
