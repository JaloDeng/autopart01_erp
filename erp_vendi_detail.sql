-- set foreign_key_checks = 0;
-- 
-- DROP TABLE IF EXISTS erp_vendi_detail;
-- CREATE TABLE `erp_vendi_detail` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `erp_inquiry_bil_id` bigint(20) NOT NULL COMMENT '询价单ID',
--   `erp_vendi_bil_id` bigint(20) DEFAULT NULL COMMENT '销售单ID。非空已转为销售单',
--   `nameAs` varchar(255) NOT NULL COMMENT '配件描述',
--   `goodsId` bigint(20) DEFAULT NULL COMMENT '配件',
--   `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商 跟单填写',
--   `isBuy` tinyint(4) DEFAULT '1' COMMENT '客户是否购买。1：需要采购',
--   `isEnough` tinyint(4) DEFAULT '1' COMMENT '该订单需求的商品是否足够销售。isEnough = 1 才可以提交出仓发货',
--   `qty` int(11) NOT NULL COMMENT '数量',
--   `ers_packageAttr_id` bigint(20) DEFAULT NULL COMMENT '商品的包装ID',
--   `unit` varchar(30) DEFAULT NULL COMMENT '单位 冗余 erp_goods_unit',
--   `packageQty` int(11) DEFAULT '0' COMMENT '包装数量',
--   `packagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装进货单价 是否需要',
--   `packageUnit` varchar(30) DEFAULT NULL COMMENT '包裹单位 是否需要',
--   `price` decimal(20,4) DEFAULT NULL COMMENT '进价',
--   `amt` decimal(20,4) DEFAULT NULL COMMENT '进价金额',
--   `salesPrice` decimal(20,4) DEFAULT NULL COMMENT '售价',
--   `salesPackagePrice` decimal(20,4) DEFAULT NULL COMMENT '包装单价',
--   `salesAmt` decimal(20,4) DEFAULT NULL COMMENT '售价金额',
--   `priceTune` decimal(20,4) DEFAULT NULL COMMENT '折后金额 暂时不需要',
--   `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
--   `updatedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
--   `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新修改时间；--@LastModifiedDate',
--   `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
--   `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
--   `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
--   `lastModifiedBy` varchar(100) DEFAULT NULL COMMENT '最新修改人员；--@LastModifiedBy',
--   `customerId` bigint(20) DEFAULT NULL COMMENT '客户',
--   `custVhclId` bigint(20) DEFAULT NULL COMMENT '客户车辆；--冗余便于数据采集  erc$vhcl_plate_id',
--   `vhcmId` bigint(20) DEFAULT NULL COMMENT '使用车型；--冗余便于数据采集 erv$vhcl_model_id',
--   `memo` varchar(255) DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`),
--   KEY `customerId_idx` (`customerId`),
--   KEY `supplierId_idx` (`supplierId`),
--   KEY `createdDate_idx` (`createdDate`),
--   KEY `erp_vendi_detail_ers_packageAttr_id_idx` (`ers_packageAttr_id`),
--   KEY `goodsId_idx` (`goodsId`,`ers_packageAttr_id`) USING BTREE,
--   KEY `erp_inquiry_bil_id_idx` (`erp_inquiry_bil_id`,`goodsId`,`ers_packageAttr_id`) USING BTREE,
--   KEY `erp_vendi_bil_id_idx` (`erp_vendi_bil_id`,`goodsId`,`ers_packageAttr_id`) USING BTREE,
--   CONSTRAINT `fk_erp_vendi_detail_erc$supplier_id` FOREIGN KEY (`supplierId`) REFERENCES `autopart01_crm`.`erc$supplier` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
--   CONSTRAINT `fk_erp_vendi_detail_erp_goods_id` FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
--   CONSTRAINT `fk_erp_vendi_detail_erp_inquiry_bil_id` FOREIGN KEY (`erp_inquiry_bil_id`) REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
--   CONSTRAINT `fk_erp_vendi_detail_ers_packageAttr_id` FOREIGN KEY (`ers_packageAttr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='询价、报价、销售单明细＃--sn=TB04401&type=mdsDetail&jname=VenditionDetail&title=&finds={"nameAs":1,"createdDate":1,"updatedDate":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_vendi_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_detail` FOR EACH ROW BEGIN
	DECLARE aid BIGINT;
	DECLARE aName VARCHAR(100);
	DECLARE aPrice DECIMAL(20,4);
	DECLARE aSupplierId BIGINT(20);
	DECLARE aQty INT(11);
	DECLARE aUnit VARCHAR(50);
	if exists(select 1 from autopart01_security.sec$user a where a.id = new.lastModifiedId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.lastModifiedId;
			set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName ,new.lastModifiedDate = CURRENT_TIMESTAMP();		
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定有效的创建人！';
	end if;
	IF new.goodsId > 0 THEN 
		if exists(select 1 from erp_goods a where a.id = new.goodsId) THEN
			set new.unit = (select a.unit from erp_goods a where a.id = new.goodsId);
		ELSE
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '必须指定有效商品！';
		end if;
		IF new.ers_packageAttr_id > 0 THEN
			SELECT a.newPrice,a.newSupplierId,a.actualQty,a.packageUnit INTO aPrice,aSupplierId,aQty,aUnit 
				FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
			SET new.packagePrice = aPrice, new.supplierId = aSupplierId, new.price = aPrice/aQty, new.packageUnit = aUnit;
		END IF;
	END IF;
	if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.erp_inquiry_bil_id and a.billStatus = 'checked') then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能追加配件！';
	elseif new.qty <= 0 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的数量，无法新增！';
	else
		if exists(select 1 from erp_inquiry_bil a where a.id = new.erp_inquiry_bil_id and a.isSubmit = 1) then
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '报价时，不能新增询价明细！';
		else  -- 客户 新增询价明细， 如果有进价和售价，需要进行有效性检查
			if new.packagePrice > 0 and new.salesPackagePrice > 0 THEN 
				if uf_salesPrice_isValiad(new.goodsId, new.packagePrice, new.salesPackagePrice) =0 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '商品售价不符合调价规则！';
				end if;
				-- 计算
				set new.amt = new.packageQty * new.packagePrice, new.salesAmt = new.packageQty * new.salesPackagePrice;
			end if;
		end if;
-- 记录操作记录
		insert into erp_inquiry_bilwfw(billId, billstatus, userid, name, optime)
		SELECT new.erp_inquiry_bil_id, 'append', new.lastModifiedId, '追加配件', CURRENT_TIMESTAMP()
		;
	end if;
end;;
DELIMITER ;

-- DROP TRIGGER IF EXISTS tr_erp_vendi_detail_AFTER_INSERT;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erp_vendi_detail_AFTER_INSERT` AFTER INSERT ON `erp_vendi_detail` FOR EACH ROW BEGIN
-- 
-- 			insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, name, optime)
-- 			select new.erp_inquiry_bil_id, 'append', a.creatorId, a.empId, a.empName, '追加配件',  CURRENT_TIMESTAMP()
-- 			from erp_inquiry_bil a WHERE a.id = new.erp_inquiry_bil_id;
-- end;;
-- DELIMITER ;

-- --------------------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS tr_erp_vendi_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_detail` FOR EACH ROW BEGIN
	DECLARE aid BIGINT;
	DECLARE aName VARCHAR(100);
	IF new.goodsId > 0 AND (ISNULL(old.goodsId) OR new.goodsId <> old.goodsId) THEN 
		if exists(select 1 from erp_goods a where a.id = new.goodsId) THEN
			set new.unit = (select a.unit from erp_goods a where a.id = new.goodsId);
		ELSE
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '必须指定有效商品！';
		end if;
	END IF;
	IF new.ers_packageAttr_id > 0 AND (ISNULL(old.ers_packageAttr_id) OR new.ers_packageAttr_id <> old.ers_packageAttr_id) THEN
			SET new.packageUnit = (SELECT a.packageUnit FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id);
	END IF;
	if new.lastModifiedId > 0 and (isnull(old.lastModifiedId) or new.lastModifiedId <> old.lastModifiedId) then
		if exists(select 1 from autopart01_security.sec$user a where a.id = new.lastModifiedId) THEN
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.lastModifiedId;
				set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName ,new.lastModifiedDate = CURRENT_TIMESTAMP();		
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改操作记录，必须指定有效的操作人！';
		end if;
	end if;
	if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.erp_inquiry_bil_id and a.billStatus = 'submitthatview') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交审核，不能修改！';
	elseif exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.erp_inquiry_bil_id and a.billStatus = 'checked') then
		if new.erp_vendi_bil_id > 0 and new.erp_inquiry_bil_id > 0 then
			IF new.isEnough = old.isEnough THEN -- 转为销售订单后，仅能修改库存是否足够
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能修改！';
			end if;
		else
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能修改！';
		end if;
	elseif new.qty < 1 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的数量，无法修改！';
	else
		if exists(select 1 from erp_inquiry_bil a where a.id = new.erp_inquiry_bil_id and a.isSubmit = 0) then  -- 客服修改询价明细
			if (new.packagePrice > 0 and (isnull(old.packagePrice) or new.packagePrice <> old.packagePrice)) THEN -- 修改了进价
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '客服不能修改进货价格！';
			end if;
			if new.salesPackagePrice > 0 and (isnull(old.salesPackagePrice) or new.salesPackagePrice <> old.salesPackagePrice > 0) then
				-- 如果客服修改了售价，需要进行售价有效性检查
				if uf_salesPrice_isValiad(new.goodsId, new.packagePrice, new.salesPackagePrice) = 0 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '商品售价不符合调价规则！';
				end if;
			end if;
		ELSE -- 跟单
			if new.salesPackagePrice > 0 and (isnull(old.salesPackagePrice) or new.salesPackagePrice <> old.salesPackagePrice > 0) then
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '跟单不能修改销售价格！';
			end if;
			
			if (new.packagePrice > 0 and (isnull(old.packagePrice) or new.packagePrice <> old.packagePrice))  THEN -- 修改了进价, 需要重新计算售价
				set new.salesPackagePrice = uf_salesPrice_calc(new.goodsId, new.packagePrice);
				set new.salesAmt = new.salesPackagePrice * new.packageQty;
				set new.salesPrice = new.salesAmt / new.qty;
			end if;
		end if;
		-- 计算销售金额及进货金额
		if new.packagePrice > 0 then 
			set new.amt = new.packageQty * new.packagePrice, new.price = new.amt/new.qty; 
		end if;
		if new.salesPackagePrice > 0 then set new.salesAmt = new.salesPackagePrice * new.packageQty; end if;

		IF new.isEnough = old.isEnough AND ISNULL(new.erp_vendi_bil_id) THEN 
			-- 记录操作记录
			insert into erp_inquiry_bilwfw(billId, billstatus, userid, name, optime)
			SELECT new.erp_inquiry_bil_id, 'selfupdated', new.lastModifiedId, '自行修改', CURRENT_TIMESTAMP()
			;
		END IF;
	end if;
end;;
DELIMITER ;
-- --------------------------------------------------------------------------------------------

-- DROP TRIGGER IF EXISTS tr_erp_vendi_detail_AFTER_UPDATE;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erp_vendi_detail_AFTER_UPDATE` AFTER UPDATE ON `erp_vendi_detail` FOR EACH ROW BEGIN
-- 		记录操作记录
-- 		insert into erp_inquiry_bilwfw(billId, billstatus, userid, name, optime)
-- 		SELECT new.erp_inquiry_bil_id, 'selfupdated', a.creatorId, '自行修改', CURRENT_TIMESTAMP()
-- 		from erp_inquiry_bil a WHERE a.id = new.erp_inquiry_bil_id;
-- 
-- END;;
-- DELIMITER ;
DROP TRIGGER IF EXISTS tr_erp_vendi_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_detail` FOR EACH ROW BEGIN
	if old.id > 0 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '不能删除询价明细！';
	end if;
end;;
DELIMITER ;