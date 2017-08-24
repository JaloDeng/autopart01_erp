-- DROP TABLE IF EXISTS erp_purch_detail;
-- CREATE TABLE `erp_purch_detail` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `erp_purch_bil_id` bigint(20) NOT NULL COMMENT '采购订单主表ID',
--   `goodsId` bigint(20) NOT NULL COMMENT '配件',
--   `ers_packageAttr_id` bigint(20) NOT NULL COMMENT '商品的包装ID',
--   `packageQty` int(11) NOT NULL DEFAULT '0' COMMENT '包装数量',
--   `packageUnit` varchar(30) DEFAULT NULL COMMENT '包裹单位 是否需要',
--   `qty` int(11) DEFAULT NULL COMMENT '单品数量',
--   `unit` varchar(255) DEFAULT NULL COMMENT '单位',
--   `packagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装单价',
--   `price` decimal(20,4) DEFAULT '0.0000' COMMENT '进价',
--   `amt` decimal(20,4) DEFAULT '0.0000' COMMENT '进价金额',
--   `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
--   `updatedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
--   `memo` varchar(255) DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`),
--   KEY `goodsId_idx` (`goodsId`),
--   KEY `erp_purch_detail_ers_packageAttr_id_idx` (`ers_packageAttr_id`),
--   KEY `createdDate_idx` (`createdDate`),
--   KEY `fk_erp_purch_detail_erp_purch_bil_id` (`erp_purch_bil_id`),
--   CONSTRAINT `fk_erp_purch_detail_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) REFERENCES `erp_purch_bil` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
--   CONSTRAINT `fk_erp_purch_detail_ers_packageAttr_id` FOREIGN KEY (`ers_packageAttr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购单明细＃--sn=TB03002&type=mdsDetail&jname=PurchaseDetail&title=&finds={"itemId":1,"createdDate":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_purch_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_detail` FOR EACH ROW BEGIN
	declare msg VARCHAR(1000);
	declare aQty int;
	declare aUnit,pUnit varchar(30);
		SET new.updatedDate = CURRENT_TIMESTAMP();
		SELECT a.unit into aUnit FROM erp_goods a WHERE a.id = new.goodsId;
		if aUnit > '' then 
			set new.unit = aUnit;
		ELSE
			set msg = concat('采购商品（编号：', new.goodsId,'）不存在！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		IF new.packageQty > 0 THEN
			if new.packagePrice > 0 THEN
				set new.amt = new.packageQty * new.packagePrice;
				SELECT a.actualQty,a.packageUnit into aQty,pUnit FROM ers_packageattr a 
				WHERE a.id = new.ers_packageAttr_id;
				set new.qty = new.packageQty * aQty, new.price = new.packagePrice / aQty;
				set new.packageUnit = pUnit;
			ELSE
				set msg = concat('采购商品（编号：', new.goodsId,'）包装单价必须大于0！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		ELSE
			set msg = concat('采购商品（编号：', new.goodsId,'）包装数量必须大于0！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
end;;
DELIMITER ;

DROP TRIGGER IF EXISTS tr_erp_purch_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_detail` FOR EACH ROW BEGIN
	declare msg VARCHAR(1000);
	declare aQty int;
	declare pUnit VARCHAR(30);
	if exists(select 1 from erp_purch_bil a where a.id = NEW.erp_purch_bil_id and a.costTime is not null) then
			set msg = concat('采购订单（编号：', new.erp_purch_bil_id, ', ）', '已审核汇款，不能修改采购明细！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif new.goodsId <> old.goodsId THEN
		SIGNAL SQLSTATE 'HY000' SET message_text = '不能变更采购商品！';
	end if;
		
		IF new.packageQty > 0 THEN
			IF new.packagePrice > 0 THEN
				if new.ers_packageAttr_id <> old.ers_packageAttr_id or new.packagePrice <> old.packagePrice THEN
					SELECT a.actualQty,a.packageUnit into aQty,pUnit FROM ers_packageattr a 
					WHERE a.id = new.ers_packageAttr_id;
					set new.qty = new.packageQty * aQty, new.price = new.packagePrice / aQty;
					set new.packageUnit = pUnit;
				end if;
				if new.packagePrice <> old.packagePrice or new.packageQty <> old.packageQty THEN
					set new.amt = new.packageQty * new.packagePrice;
				end if;
				SET new.updatedDate = CURRENT_TIMESTAMP();
			ELSE
				set msg = concat('采购商品（编号：', new.goodsId,'）包装单价必须大于0！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		ELSE
			set msg = concat('采购商品（编号：', new.goodsId,'）包装数量必须大于0！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
end;;
DELIMITER ;

DROP TRIGGER IF EXISTS tr_erp_purch_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_purch_detail` FOR EACH ROW BEGIN
	declare msg VARCHAR(1000);

	if exists(select 1 from erp_purch_bil a where a.id = old.erp_purch_bil_id and a.costTime > '') then
			set msg = concat('采购订单（编号：', old.erp_purch_bil_id, ', ）', '已审核付款，不能删除采购明细！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

end;;
DELIMITER ;