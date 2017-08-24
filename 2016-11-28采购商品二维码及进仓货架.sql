set FOREIGN_key_checks = 0;

-- ----------------------------
--  Table structure for `erp_purchDetail_snCode`
-- ----------------------------
-- 生成单品的二维码，若包装不是单品，则还需生成包装的二维码
-- 记录进仓的货架
DROP TABLE IF EXISTS `erp_purch_bil_intosnc`;
DROP TABLE IF EXISTS `erp_purchDetail_snCode`;
CREATE TABLE `erp_purchDetail_snCode` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_detail_id` bigint(20) NOT NULL COMMENT '采购单明细ID',
--   `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
--   `roomId` bigint(20) DEFAULT NULL COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库',
  `ers_shelfattr_id` bigint(20) default NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`snCode` VARCHAR(1850) DEFAULT NULL COMMENT '包裹扫描码',
  PRIMARY KEY (`id`),
	KEY `erp_purchDetail_snCode_erp_purch_bil_id_idx` (`erp_purch_bil_id`),
-- 	KEY `erp_purchDetail_snCode_goodsId_idx` (`goodsId`),
	KEY `erp_purchDetail_snCode_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
	KEY `erp_purchDetail_snCode_ers_packageattr_id_idx` (`ers_packageattr_id`),
	KEY `erp_purchDetail_snCode_snCode_idx` (`snCode`),
-- 	CONSTRAINT `fk_erp_purchDetail_snCode_goodsId` FOREIGN KEY (`goodsId`) 
-- 		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_purchDetail_snCode_erp_purch_detail_id` FOREIGN KEY (`erp_purch_detail_id`) 
		REFERENCES `erp_purch_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purchDetail_snCode_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) 
		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 
COMMENT='包裹采购进仓逐个条码＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;

drop TRIGGER if exists tr_erp_purchDetail_snCode_before_insert;
DELIMITER $$
CREATE TRIGGER `tr_erp_purchDetail_snCode_before_insert` BEFORE INSERT ON `erp_purchDetail_snCode`
FOR EACH ROW begin
	DECLARE aid int;
	declare iCount int;  -- 计数器 初始值 = 包裹深度
	declare aQty dec(20,2);  -- 组成单位的数量
	declare tQty dec(20,2);  -- 包裹包含的单品的数量
	declare tCode varchar(255);  -- 生成的tierCode
	if new.parentId > 0 then
		if new.childCount < 2 or isnull(new.childCount) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增商品非单品包装规格时，组成单位的数量必须大于1！';
		end if;
		set new.degree = (select a.degree + 1 from ers_packageAttr a where a.id = new.parentId);
		set aid = new.parentId, tQty = new.childCount;
		set iCount = new.degree - 1;
		set tCode = concat(aid, ']');
		if iCount > 1 then
			set tCode = concat(',', tCode); 
			while iCount > 1 do
				select a.parentId, a.childCount * tQty into aid, tQty
				from ers_packageAttr a where a.id = aid;
				set tCode = concat(aid, tCode);
				set iCount = iCount - 1;
				if iCount > 1 then 
					set tCode = concat(',', tCode); 
				ELSE
					set tCode = concat('[', tCode); 
				end if;
			end while; 
		ELSE
			set tCode = concat('[', tCode); 
		end if;
		set new.actualQty = tQty, new.tierCode = tCode;
	ELSE
		set new.degree = 1, new.actualQty = 1, new.childCount = 1, new.tierCode = '[]';
	end if;
end$$
DELIMITER ;

-- ----------------------------
--  Table structure for `erp_purch_bil_intoqty`
-- ----------------------------
-- 采购进仓，一条采购明细可以对应多条进仓记录（因为一条明细可以分别存储在不同的货架）
drop table IF EXISTS `erp_purch_bil_intoqty`;
DROP TABLE IF EXISTS `erp_purchDetail_shelfQty`;
CREATE TABLE `erp_purchDetail_shelfQty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_detail_id` bigint(20) NOT NULL COMMENT '采购单ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `roomId` bigint(20) DEFAULT NULL COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库',
  `shelfId` bigint(20) NOT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
	`qty` DECIMAL(20,4) DEFAULT NULL COMMENT '数量；--最小粒度单位的数量',
  PRIMARY KEY (`id`),
	KEY `erp_purch_bil_intoqty_erp_purch_bil_id_idx` (`erp_purch_bil_id`),
	KEY `erp_purch_bil_intoqty_goodsId_idx` (`goodsId`),
	KEY `erp_purch_bil_intoqty_shelfId_idx` (`shelfId`),
	KEY `erp_purch_bil_intoqty_ers_packageattr_id_idx` (`ers_packageattr_id`),
	CONSTRAINT `fk_erp_purch_bil_intoqty_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_purch_bil_intoqty_erp_purch_detail_id` FOREIGN KEY (`erp_purch_detail_id`) 
		REFERENCES `erp_purch_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_bil_intoqty_shelfId` FOREIGN KEY (`shelfId`) 
		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
	CONSTRAINT `fk_erp_purch_bil_intoqty_ers_packageattr_id` FOREIGN KEY (`ers_packageattr_id`) 
		REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 
COMMENT='包裹采购进仓数目计量＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds='
;

