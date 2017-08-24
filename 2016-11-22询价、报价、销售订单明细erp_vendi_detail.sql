SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for erp_vendi_detail
-- ----------------------------
DROP TABLE IF EXISTS `erp_vendi_detail`;
CREATE TABLE `erp_vendi_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
	erp_inquiry_bil_id BIGINT(20) not null COMMENT '询价单ID',
  `nameAs` varchar(255) NOT NULL COMMENT '配件描述',
  `goodsId` bigint(20) NOT NULL COMMENT '配件',
  `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商 跟单填写',
	isBuy TINYINT DEFAULT 1 COMMENT '客户是否购买。1：需要采购',
	isEnough TINYINT default 1 COMMENT '该订单需求的商品是否足够销售。isEnough = 1 才可以提交出仓发货',
  `qty` decimal(20,4) NOT NULL COMMENT '数量',
	ers_packageAttr_id BIGINT(20) not null COMMENT '商品的包装ID',
  `unit` varchar(30) NOT NULL COMMENT '单位 冗余 erp_goods_unit',
  `packs` decimal(20,4) DEFAULT NULL COMMENT '件数 提货信息  暂时不需要',
  `packsUnit` varchar(255) DEFAULT NULL COMMENT '包装 提货信息  暂时不需要',
  `price` decimal(20,4) DEFAULT NULL COMMENT '进价',
  `amt` decimal(20,4) DEFAULT NULL COMMENT '进价金额',
  `salesPrice` decimal(20,4) DEFAULT NULL COMMENT '售价',
  `salesAmt` decimal(20,4) DEFAULT NULL COMMENT '售价金额',
  `priceTune` decimal(20,4) DEFAULT NULL COMMENT '折后金额 暂时不需要',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `updatedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
  `customerId` bigint(20) DEFAULT NULL COMMENT '客户',
  `custVhclId` bigint(20) DEFAULT NULL COMMENT '客户车辆；--冗余便于数据采集  erc$vhcl_plate_id',
  `vhcmId` bigint(20) DEFAULT NULL COMMENT '使用车型；--冗余便于数据采集 erv$vhcl_model_id',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `customerId_idx` (`customerId`),
  KEY `supplierId_idx` (`supplierId`),
  KEY `createdDate_idx` (`createdDate`),
  KEY `goodsId_idx` (`goodsId`) USING BTREE,
  CONSTRAINT `fk_erp_vendi_detail_erp_goods_id` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_vendi_detail_erc$supplier_id` FOREIGN KEY (`supplierId`) 
		REFERENCES `autopart01_crm`.`erc$supplier` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8mb4 
COMMENT='询价、报价、销售单明细＃--sn=TB04401&type=mdsDetail&jname=VenditionDetail&title=&finds={"nameAs":1,"createdDate":1,"updatedDate":1}'
;
-- *****************************************************************************************************
-- 创建函数 uf_salesPrice_calc, 通过商品ID、进货价按照调价规则获得商品的售价
-- *****************************************************************************************************
drop FUNCTION if exists uf_salesPrice_calc;
DELIMITER $$
create FUNCTION uf_salesPrice_calc(
	gid	bigint(20)	-- 商品ID
	, price decimal(20, 6)  -- 进货价
)
RETURNS decimal(20, 6)
begin
	declare aRatio, aFloatMin, aFloatMax decimal(20,6);
	DECLARE msg varchar(1000);
	if exists(select 1 from `erp_conf_price_tune_rule` a where a.goodsId = gid) then
			select a.ratio * price, a.floatMin * price, a.floatMax * price into aRatio, aFloatMin, aFloatMax
			from autopart01_erp.erp_conf_price_tune_rule a 
			where a.goodsId = gid; 
	ELSE
			select a.ratio * price, a.floatMin * price, a.floatMax * price into aRatio, aFloatMin, aFloatMax
			from v_goodsdefultrule a;
	end if;

	if(aRatio < aFloatMin) then 
			set msg = CONCAT('售价不能低于', round(aFloatMin, 2), '!');
			signal sqlstate 'HY000' set message_text = msg;
	elseif(aRatio > aFloatMax) then 
			set msg = CONCAT('售价不能高于', round(aFloatMax, 2), '!');
			signal sqlstate 'HY000' set message_text = msg;
	end if;
	return aRatio;
end$$
DELIMITER ;
-- *****************************************************************************************************
-- 创建函数 uf_salesPrice_isValiad, 通过商品ID、进货价、销售价按照调价规则判断获得商品的售价是否有效
-- *****************************************************************************************************
drop FUNCTION if exists uf_salesPrice_isValiad;
DELIMITER $$
create FUNCTION uf_salesPrice_isValiad(
	gid	bigint(20)	-- 商品ID
	, price decimal(20, 6)  -- 进货价
	, sPrice decimal(20, 6)  -- 销售价
)
RETURNS TINYINT
begin
	declare aRatio, aFloatMin, aFloatMax decimal(20,6);
	DECLARE msg varchar(1000);
	if exists(select 1 from `erp_conf_price_tune_rule` a where a.goodsId = gid) then
			select a.floatMin * price, a.floatMax * price into aFloatMin, aFloatMax
			from autopart01_erp.erp_conf_price_tune_rule a 
			where a.goodsId = gid; 
	ELSE
			select a.floatMin * price, a.floatMax * price into aFloatMin, aFloatMax
			from v_goodsdefultrule a;
	end if;

	if(sPrice < aFloatMin) then 
			set msg = CONCAT('售价不能低于', round(aFloatMin, 2), '!');
			signal sqlstate 'HY000' set message_text = msg;
		return 0;
	elseif(sPrice > aFloatMax) then 
			set msg = CONCAT('售价不能高于', round(aFloatMax, 2), '!');
			signal sqlstate 'HY000' set message_text = msg;
		return 0;
	end if;
	return 1;
end$$
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_salesPrice_calc, 通过商品ID、进货价按照调价规则获得商品的售价、最低限价、最高限价
-- *****************************************************************************************************
drop PROCEDURE if exists p_salesPrice_calc;
DELIMITER $$
create PROCEDURE p_salesPrice_calc(
	gid	bigint(20)	-- 商品ID
	, price decimal(20, 6)  -- 进货价
)
begin
	declare aRatio, aFloatMin, aFloatMax decimal(20,6);
	DECLARE msg varchar(1000);
	if exists(select 1 from `erp_conf_price_tune_rule` a where a.goodsId = gid) then
			select a.ratio * price, a.floatMin * price, a.floatMax * price into aRatio, aFloatMin, aFloatMax
			from autopart01_erp.erp_conf_price_tune_rule a 
			where a.goodsId = gid; 
	ELSE
			select a.ratio * price, a.floatMin * price, a.floatMax * price into aRatio, aFloatMin, aFloatMax
			from v_goodsdefultrule a;
	end if;

	if(aRatio < aFloatMin) then 
			set msg = CONCAT('售价不能低于', round(aFloatMin, 2), '!');
			signal sqlstate 'HY000' set message_text = msg;
	elseif(aRatio > aFloatMax) then 
			set msg = CONCAT('售价不能高于', round(aFloatMax, 2), '!');
			signal sqlstate 'HY000' set message_text = msg;
	end if;
	select aRatio, aFloatMin, aFloatMax;
end$$
DELIMITER ;
-- ----------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_detail_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_detail` FOR EACH ROW BEGIN
	if exists(select 1 from erp_goods a where a.id = new.goodsId) THEN
		set new.unit =(select a.unit from erp_goods a where a.id = new.goodsId);
	ELSE
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增询价明细，必须指定商品！';
	end if;
	if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.erp_inquiry_bil_id and a.billStatus = 'checked') then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能追加配件！';
	elseif new.qty <= 0 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的数量，无法新增！';
	else
		if exists(select 1 from erp_inquiry_bil a where a.id = new.erp_inquiry_bil_id and a.isSubmit = 1) then
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '报价时，不能新增询价明细！';
		else  -- 新增询价明细
			if new.price > 0 or new.salesPrice > 0 THEN -- 指定了进价或者售价
				SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增询价明细，不能指定进货价格或销售价格！';
			end if;
		end if;
		if exists(select 1 from erp_vendi_detail a where a.erp_inquiry_bil_id = NEW.erp_inquiry_bil_id) then
			insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, name, optime)
			select new.erp_inquiry_bil_id, 'append', a.creatorId, a.empId, a.empName, '追加配件',  CURRENT_TIMESTAMP()
			from erp_inquiry_bil a;
		ELSE
			insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, name, optime)
			select new.erp_inquiry_bil_id, 'justcreated', a.creatorId, a.empId, a.empName, '刚刚创建',  CURRENT_TIMESTAMP()
			from erp_inquiry_bil a;
		end if;
	end if;
end;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_detail_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_detail` FOR EACH ROW BEGIN
	DECLARE aPrice DECIMAL(20,6);
	if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.erp_inquiry_bil_id and a.billStatus = 'submitthatview') then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已提交审核，不能修改！';
	elseif exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.erp_inquiry_bil_id and a.billStatus = 'checked') then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该单据已转为销售订单，不能修改！';
	elseif new.qty = 0 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的数量，无法修改！';
	else
		if exists(select 1 from erp_inquiry_bil a where a.id = new.erp_inquiry_bil_id and a.isSubmit = 0) then  -- 客服修改询价明细
			if (new.price > 0 and (isnull(old.price) or new.price <> old.price)) THEN -- 修改了进价
				SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '客服不能修改进货价格！';
			end if;
			IF (new.salesPrice > 0 AND (ISNULL(old.salesPrice) OR new.salesPrice <> old.salesPrice > 0)) THEN -- 客服填写售价或者改售价
				IF EXISTS(SELECT 1 FROM erp_goods a WHERE a.id = new.goodsId AND a.newPrice > 0) THEN -- 该商品有最新售价
					IF EXISTS(SELECT 1 FROM erp_goodsbook a WHERE a.goodsId = new.goodsId AND a.newPrice > 0) THEN -- 该商品有最新进货价
						SET aPrice = (SELECT a.newPrice FROM erp_goodsbook a WHERE a.goodsId = new.goodsId);	-- 用最新进货价判断售价是否合理
						IF uf_salesPrice_isValiad(new.goodsId, aPrice, new.salesPrice) = 0 THEN 
							SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '商品售价不符合调价规则';
						END IF;
					-- 如果erp_goodsbook表没有最新进货价,跟单直接在明细上面填写的(还没有进货时可能没有最新进货价)
					ELSEIF(SELECT 1 FROM erp_vendi_detail a WHERE a.goodsId = new.goodsId AND a.price > 0) THEN 
						-- 用跟单最新填写的进货价判断售价是否合理
						SET aPrice = (SELECT a.newPrice FROM erp_vendi_detail a WHERE a.goodsId = new.goodsId ORDER BY a.id DESC LIMIT 1);	
						IF uf_salesPrice_isValiad(new.goodsId, aPrice, new.salesPrice) = 0 THEN 
							SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '商品售价不符合调价规则';
						END IF;
					ELSE 
						SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = 'error1:该商品需要向跟单部询价后才能填写售价!'; -- 没有最新进货价时要向跟单询价
					END IF;
				ELSE
					SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = 'error2:该商品需要向跟单部询价后才能填写售价!'; -- 没有最新售价时要向跟单询价
				END IF;
			END IF;--
		ELSE -- 跟单修改询价明细
			if (new.price > 0 and (isnull(old.price) or new.price <> old.price)) or 
			(new.salesPrice > 0 and (isnull(old.salesPrice) or new.salesPrice <> old.salesPrice > 0)) THEN -- 修改了进价或者售价		
-- 				if isnull(old.salesPrice) then 
-- 					set new.salesPrice = uf_salesPrice_calc(new.goodsId,new.price);	-- 自动生成售价
-- 				end if;
-- 				if uf_salesPrice_isValiad(new.goodsId, new.price, new.salesPrice) = 0 THEN
-- 					SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '商品售价不符合调价规则';
-- 				end if;
-- 				if new.price > 0 then set new.amt = new.qty * new.price; end if;
-- 				if new.salesPrice > 0 then set new.salesAmt = new.qty * new.salesPrice; end if;
			BEGIN END;
			end if;
		end if;
		if old.price <> new.price then 
			insert into erp_inquiry_bilwfw(billId, billstatus, userid, name, optime)
			SELECT new.id, 'selfupdated', a.updaterId, '自行修改', CURRENT_TIMESTAMP()
			from erp_inquiry_bil a;
		end if;
	end if;
END
;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_detail_BEFORE_DELETE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_detail` FOR EACH ROW BEGIN
	if old.id > 0 then
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '不能删除询价明细！';
	end if;
end;;
DELIMITER ;
