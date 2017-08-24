-- -----------------------------------------------------------------------------------------------------
-- 采购退货进仓数量记录
-- -----------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_purch_back_goutqty`;
CREATE TABLE `erp_purch_back_goutqty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purchDetail_snCode_id` bigint(20) NOT NULL COMMENT '配件二维码ID',
  `erp_purch_back_id` bigint(20) NOT NULL COMMENT '采购退货单ID',
  `erp_purch_back_detail_id` bigint(20) NOT NULL COMMENT '采购退货单明细ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `roomId` bigint(20) DEFAULT NULL COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库',
  `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
  `packageQty` int(11) DEFAULT '0' COMMENT '数量；--包装数量',
  `qty` decimal(20,4) DEFAULT NULL COMMENT '数量；--最小粒度单位的数量',
  `outTime` datetime DEFAULT NULL COMMENT '出仓时间 ',
  `outUserId` bigint(20) DEFAULT NULL COMMENT '出仓人 ',
  `outEmpId` bigint(20) DEFAULT NULL COMMENT '出仓员工ID',
  `outEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '员工姓名',
  PRIMARY KEY (`id`),
  KEY `purch_back_goutqty_purch_back_detail_id_idx` (`erp_purch_back_detail_id`,`goodsId`) USING BTREE,
  KEY `purch_back_goutqty_purchDetail_snCode_id_idx` (`erp_purchDetail_snCode_id`) USING BTREE,
  CONSTRAINT `fk_purch_back_goutqty_purch_back_detail_id` FOREIGN KEY (`erp_purch_back_detail_id`) 
		REFERENCES `erp_purch_back_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_purch_back_goutqty_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_purch_back_goutqty_shelfId` FOREIGN KEY (`ers_shelfattr_id`) 
		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='采购退货进仓数量明细'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_goutqty_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_goutqty_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_back_goutqty` FOR EACH ROW BEGIN
	
	DECLARE msg VARCHAR(1000);

	SET msg = CONCAT('（二维码编号：', IFNULL(new.erp_purchDetail_snCode_id, ''), '）采购退货出仓时，');
	-- 更新仓位库存账簿
	if exists(select 1 from ers_shelfBook a 
			where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id
		) then

		update ers_shelfBook a 
		set a.packageQty = a.packageQty - new.packageQty, a.qty = a.qty - new.qty
		where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能同步修改仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

		-- 修改日记账账簿静态库存
		update erp_goods_jz_day a 
		set a.purchBackStaticQty = a.purchBackStaticQty - new.qty
		where a.goodsId = new.goodsId and a.datee = CURDATE();
		if ROW_COUNT() = 0 THEN
			SET msg = CONCAT(msg, '未能成功修改日记账账簿静态态库存！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
	else
		SET msg = CONCAT(msg, '不存在该配件的仓位账簿记录！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- DROP TRIGGER IF EXISTS tr_erp_purch_back_goutqty_BEFORE_UPDATE;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erp_purch_back_goutqty_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_back_goutqty` FOR EACH ROW BEGIN
-- 
-- END;;
-- DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_goutqty_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_goutqty_BEFORE_DELETE` BEFORE DELETE ON `erp_purch_back_goutqty` FOR EACH ROW BEGIN

	DECLARE msg VARCHAR(1000);

	if old.qty > 0 THEN
		update ers_shelfBook a 
			set a.packageQty = a.packageQty + old.packageQty, a.qty = a.qty  + old.qty
		where a.ers_packageattr_id = old.ers_packageattr_id and a.ers_shelfattr_id = old.ers_shelfattr_id;
		if ROW_COUNT() = 0 THEN
			set msg = concat('删除配件（编号：', old.goodsId,'）库房（编号', old.roomId,'）仓位（编号：）'
			, old.ers_shelfattr_id,'）的出仓单明细时，');
				set msg = concat(msg, '未能同步修改仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 修改日记账账簿静态库存
		update erp_goods_jz_day a 
			set a.purchBackStaticQty = a.purchBackStaticQty + old.qty
		where a.goodsId = old.goodsId and a.datee = CURDATE();
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购退货出仓时，未能成功修改日记账账簿静态态库存！';
		end if;
	end if;

END;;
DELIMITER ;