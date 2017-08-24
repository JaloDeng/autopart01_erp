-- -----------------------------------------------------------------------------------------------------
-- 销售退货进仓数量记录
-- -----------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_back_intoqty;
CREATE TABLE `erp_vendi_back_intoqty` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purchDetail_snCode_id` bigint(20) NOT NULL COMMENT '配件二维码ID',
  `erp_vendi_back_id` bigint(20) NOT NULL COMMENT '销售退货单主表ID 冗余',
  `erp_vendi_back_detail_id` bigint(20) NOT NULL COMMENT '销售退货单明细ID',
  `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
  `roomId` bigint(20) DEFAULT NULL COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库',
  `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
  `packageQty` int(11) DEFAULT '0' COMMENT '数量；--包装数量',
  `qty` int(11) DEFAULT '0' COMMENT '数量；--最小粒度单位的数量',
  `inTime` datetime DEFAULT NULL COMMENT '进仓时间 非空时已出仓可发货',
  `inUserId` bigint(20) DEFAULT NULL COMMENT '进人 ',
  `inEmpId` bigint(20) DEFAULT NULL COMMENT '出仓员工ID；--@  erc$staff_id',
  `inEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '员工姓名。是执行checked的员工',
  PRIMARY KEY (`id`),
  KEY `vendi_back_intoqty_snCode_id_idx` (`erp_purchDetail_snCode_id`),
  KEY `vendi_back_intoqty_vendi_back_detail_id` (`erp_vendi_back_detail_id`,`ers_shelfattr_id`,`erp_purchDetail_snCode_id`),
  KEY `vendi_back_intoqty_goodsId` (`goodsId`,`erp_vendi_back_detail_id`,`ers_shelfattr_id`),
  KEY `vendi_back_intoqty_goodsId1_idx` (`goodsId`,`ers_shelfattr_id`),
  KEY `vendi_back_intoqty_ers_packageattr_id_idx` (`ers_packageattr_id`),
  KEY `vendi_back_intoqty_ers_shelfattr_id` (`ers_shelfattr_id`,`ers_packageattr_id`,`erp_vendi_back_detail_id`) USING BTREE,
  CONSTRAINT `fk_vendi_back_intoqty_vendi_back_detail_id` FOREIGN KEY (`erp_vendi_back_detail_id`) 
		REFERENCES `erp_vendi_back_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_vendi_back_intoqty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) 
		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_vendi_back_intoqty_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售退货进仓数量明细'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_intoqty_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_intoqty_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_back_intoqty` FOR EACH ROW BEGIN
	
	DECLARE msg VARCHAR(1000);

	SET msg = CONCAT('（二维码编号：', IFNULL(new.erp_purchDetail_snCode_id, ''), '）销售退货进仓时，');

	-- 修改动态库存
	if not exists(SELECT 1 FROM erp_goodsbook a WHERE a.goodsId = new.goodsId) THEN
		insert into erp_goodsbook(goodsid)
		select new.goodsId;
		if ROW_COUNT() = 0 THEN
			set msg = concat(msg, '创建配件账簿失败！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
	end if;
	-- 修改账簿动态库存
	update erp_goodsbook a set a.dynamicQty = a.dynamicQty + new.qty, a.changeDate = CURDATE()
	WHERE a.goodsId = new.goodsId;
	if ROW_COUNT() <> 1 THEN
		set msg = concat(msg, '未能成功修改账簿动态库存！') ;
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 更新仓位库存账簿
	if exists(select 1 from ers_shelfBook a 
			where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id 
		) then

		update ers_shelfBook a 
		set a.packageQty = a.packageQty + new.packageQty, a.qty = a.qty + new.qty
		where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id;
		IF ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能同步修改仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;

	else

		insert into ers_shelfBook(goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty) 
		select new.goodsId, new.ers_packageattr_id, new.roomId, new.ers_shelfattr_id, new.packageQty, new.qty;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能同步新增仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

	end if;

	-- 修改日记账账簿静态库存
	update erp_goods_jz_day a 
	set a.salesBackStaticQty = a.salesBackStaticQty + new.qty, a.salesBackDynaimicQty = a.salesBackDynaimicQty + new.qty
	where a.goodsId = new.goodsId and a.datee = CURDATE();
	if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改日记账账簿静态库存！';
	end if;
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_intoqty_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_intoqty_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_back_intoqty` FOR EACH ROW BEGIN

	DECLARE msg VARCHAR(1000);

	set msg = concat('修改配件（编号：', new.goodsId,'）库房（编号', new.roomId,'）仓位（编号：'
		, new.ers_shelfattr_id,'）的销售退货进仓单明细时，');

	-- 配件、仓库、仓位不能更改
	if new.roomId <> old.roomId or new.goodsId <> old.goodsId or new.ers_shelfattr_id <> old.ers_shelfattr_id THEN
		set msg = concat(msg, '不能修改配件或者库房或者仓位！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	if new.packageQty <> old.packageQty then
		if exists(select 1 from ers_shelfBook a 
			where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id 
				and a.qty + new.qty - old.qty < 0) then
			set msg = concat(msg, '出现数量小于0的情况！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		else
			-- 修改账簿动态库存
			update erp_goodsbook a set a.dynamicQty = a.dynamicQty + new.qty - old.qty, a.changeDate = CURDATE()
			WHERE a.goodsId = new.goodsId;
			if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '未能成功修改账簿动态库存！') ;
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
			-- 修改仓位静态库存
			update ers_shelfBook a 
			set a.packageQty = a.packageQty + new.packageQty - old.packageQty, a.qty = a.qty + new.qty - old.qty
			where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id;
			if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '未能同步修改仓位账簿库存！') ;
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
		end if;

		-- 修改日记账账簿静态库存
		update erp_goods_jz_day a 
				set a.salesBackStaticQty = a.salesBackStaticQty + new.qty - old.qty, a.salesBackDynaimicQty = a.salesBackDynaimicQty + new.qty - old.qty
		where a.goodsId = new.goodsId and a.datee = CURDATE();
		if ROW_COUNT() <> 1 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货进仓时，未能成功修改日记账账簿静态库存！';
		end if;
	end if;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_intoqty_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_intoqty_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_back_intoqty` FOR EACH ROW BEGIN

	DECLARE msg VARCHAR(1000);

	if old.qty > 0 THEN
		-- 修改账簿动态库存
		update erp_goodsbook a set a.dynamicQty = a.dynamicQty - old.qty, a.changeDate = CURDATE()
		WHERE a.goodsId = old.goodsId;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能成功修改账簿动态库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 修改仓位静态库存
		update ers_shelfBook a 
			set a.packageQty = a.packageQty - old.packageQty, a.qty = a.qty  - old.qty
		where a.ers_packageattr_id = old.ers_packageattr_id and a.ers_shelfattr_id = old.ers_shelfattr_id;
		if ROW_COUNT() <> 1 THEN
			set msg = concat('删除配件（编号：', old.goodsId,'）库房（编号', old.roomId,'）仓位（编号：）'
			, old.ers_shelfattr_id,'）的销售退货进仓单明细时，');
				set msg = concat(msg, '未能同步修改仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 修改日记账账簿静态库存
		update erp_goods_jz_day a 
			set a.salesBackStaticQty = a.salesBackStaticQty - old.qty, a.salesBackDynaimicQty = a.salesBackDynaimicQty - old.qty
		where a.goodsId = old.goodsId and a.datee = CURDATE();
		if ROW_COUNT() <> 1 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货进仓时，未能成功修改日记账账簿静态态库存！';
		end if;
	end if;

END;;
DELIMITER ;