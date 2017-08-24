-- ----------------------------
--  Table structure for `erp_purch_detail`
-- ----------------------------
DROP TABLE IF EXISTS `erp_purch_detail`;
CREATE TABLE `erp_purch_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_bil_id` bigint(20) NOT NULL COMMENT '采购单主表ID',
  `goodsId` bigint(20) NOT NULL COMMENT '配件',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码；--空是从销售需求的，非空是需要进仓的 从供应商订货的',
  `mergeId` bigint(20) DEFAULT NULL COMMENT '合并到的明细编码；--空是从供应商订货的，非空是不用进仓的 从销售需求生成的',
  `qty` decimal(20,4) NOT NULL COMMENT '数量',
	`packageQty` decimal(20,4) DEFAULT NULL COMMENT '包裹数量',
  `price` decimal(20,4) DEFAULT NULL COMMENT '进价',
  `amt` decimal(20,4) DEFAULT NULL COMMENT '进价金额',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `updatedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
  `storedDate` datetime DEFAULT NULL COMMENT '进仓时间；--不为空表示已经进仓',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
	KEY `erp_purch_bil_id_idx` (`erp_purch_bil_id`),
  KEY `goodsId_idx` (`goodsId`),
	KEY `ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `mergeId_idx` (`mergeId`),
	KEY `qty_idx` (`qty`),
	KEY `packageQty_idx` (`packageQty`),
	KEY `price_idx` (`price`),
	KEY `amt_idx` (`amt`),
	KEY `mergeId_idx` (`mergeId`),
  KEY `createdDate_idx` (`createdDate`),
  KEY `fk_erp_purch_detail_erp_purch_bil_id` (`erp_purch_bil_id`),
  CONSTRAINT `fk_erp_purch_detail_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) REFERENCES `erp_purch_bil` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_purch_detail_goodsId` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_detail_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_detail_mergeId` FOREIGN KEY (`mergeId`) REFERENCES `erp_purch_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购预订单明细＃--sn=TB03002&type=mdsDetail&jname=PurchaseDetail&title=&finds={"itemId":1,"createdDate":1}';
