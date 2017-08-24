-- -----------------------------------------------------------------------------------
-- 函数:最新进货价(新增采购明细时默认显示)
-- -----------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `p_goods_snCode`;
DELIMITER ;;
CREATE PROCEDURE `p_goods_snCode`(
	pDetailid bigint(20), -- 采购明细ID
	qty decimal(20,4), -- 进货数量
	gid bigint(20) -- 商品ID
) 
begin
	INSERT INTO erp_purch_detail_shelfQty (erp_purch_detail_id,goodsId,snCode)
	VALUES (pDetailid,gid,CONCAT(purch_detail_id,qty,
		LPAD(
			IFNULL(SELECT MAX(RIGHT(a.snCode,6)) FROM erp_purch_detail_shelfQty a WHERE a.erp_purch_detail_id = pDetailid,0)
			+1,6,0)
		)
	);
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:最新进货价(新增采购明细时默认显示)
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_erp_suppliersgoods_getNewPrice`;
DELIMITER ;;
CREATE FUNCTION `uf_erp_suppliersgoods_getNewPrice`(
	gId bigint(20), -- 商品ID
	sId bigint(20) -- 供应商ID
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select a.newPrice into aPrice from `erp_suppliersgoods` a where a.goodsId = gid and a.crm_suppliers_id = sId
	IF aPrice is not null THEN 
		RETURN aPrice;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:最新进货均价
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_purch_averagePrice`;
DELIMITER ;;
CREATE FUNCTION `uf_purch_averagePrice`(
	gId bigint(20), -- 商品ID
	nPrice decimal(20,4),	-- 最新进货价
	qty decimal(20,4) -- 进货数量
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select (SUM(a.amt) + nPrice * qty) / (SUM(a.qty) + qty) into aPrice from `erp_purch_detail` a where a.goodsId = gid; 
	IF aPrice is not null THEN 
		RETURN aPrice;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:历史最高进货价
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_purch_maxPrice`;
DELIMITER ;;
CREATE FUNCTION `uf_purch_maxPrice`(
	gId bigint(20), -- 商品ID
	nPrice decimal(20,4)	-- 最新进货价
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select MAX(a.price) into aPrice from `erp_purch_detail` a where a.goodsId = gid; 
	IF aPrice > nPrice THEN 
		RETURN aPrice;
	ELSE
		RETURN nPrice;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:历史最低进货价
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_purch_minPrice`;
DELIMITER ;;
CREATE FUNCTION `uf_purch_minPrice`(
	gId bigint(20), -- 商品ID
	nPrice decimal(20,4)	-- 最新进货价
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select MIN(a.price) into aPrice from `erp_purch_detail` a where a.goodsId = gid; 
	IF aPrice < nPrice THEN 
		RETURN aPrice;
	ELSE
		RETURN nPrice;
	END IF;
end
;;
DELIMITER ;


-- -----------------------------------------------------------------------------------
-- 存储过程:采购进货修改goodsbook表的静态库存、最新进货价、最高价、最低价
-- -----------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `p_goodsbook_change_from_purch`;
DELIMITER ;;
CREATE PROCEDURE `p_goodsbook_change_from_purch`(
	gid bigint(20), -- 商品ID
	qty decimal(20,4), -- 进货数量
	nSuppliersId bigint(20),-- 最新供应商ID
	nPrice decimal(20,4)	-- 最新进货价
) 
begin
	DECLARE msg VARCHAR(100);
	IF EXISTS(SELECT 1 FROM erp_goodsbook a WHERE a.goodsId = gid) THEN 
		UPDATE erp_goodsbook a SET 
			a.dynamicQty = a.dynamicQty + qty, -- 动态库存
			a.suppliersId = nSuppliersId,	-- 最新供应商
			a.price = uf_purch_averagePrice(gid,nPrice,qty); -- 最新进货均价
			a.newPrice = nPrice, -- 最新进货价
			a.maxPrice = uf_purch_maxPrice(gid,nPrice), -- 历史最高进货价
			a.minPrice = aMinPrice, -- 历史最低进货价
			a.changeDate = CURRENT_DATE() -- 修改日期
		WHERE a.goodsId = gid;
		IF ROW_COUNT() <> 1 THEN 
			SET msg = CONCAT('商品ID:',gid,' 未能成功更新最新库存、进货价');
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 更新该供应商该商品的最新进货价,如果没有就自动插入一条
		IF EXISTS(SELECT 1 FROM erp_suppliersgoods b WHERE b.erc_suppliers_id = nSuppliersId AND b.goodsId = gid) THEN 
			UPDATE erp_suppliersgoods b SET
				b.newPrice = nPrice
			WHERE b.erc_suppliers_id = nSuppliersId AND b.goodsId = gid;
		ELSE
			-- 该表可能需要改字段名crm_suppliers_id --> erc_suppliers_id
			INSERT INTO erp_suppliersgoods (erc_suppliers_id,goodsId,newPrice) 
			VALUES (nSuppliersId,gid,nPrice);
		END IF;
		IF ROW_COUNT() <> 1 THEN 
			SET msg = CONCAT('商品ID:',gid,' 未能成功更新该供应商该商品的最新价格');
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg;
		END IF;
	ELSE 
		SET msg = CONCAT('商品ID:',gid,' 没有新建库存表');
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:最新销售均价
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_vendi_averagePrice`;
DELIMITER ;;
CREATE FUNCTION `uf_vendi_averagePrice`(
	gId bigint(20), -- 商品ID
	nPrice decimal(20,4),	-- 最新销售价
	qty decimal(20,4) -- 销售数量
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select (SUM(a.salesAmt) + nPrice * qty) / (SUM(a.qty) + qty) into aPrice from `erp_vendi_detail` a where a.goodsId = gid; 
	IF aPrice is not null THEN 
		RETURN aPrice;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:历史最高销售价
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_vendi_maxPrice`;
DELIMITER ;;
CREATE FUNCTION `uf_vendi_maxPrice`(
	gId bigint(20), -- 商品ID
	nPrice decimal(20,4)	-- 最新销售价
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select MAX(a.salesPrice) into aPrice from `erp_vendi_detail` a where a.goodsId = gid; 
	IF aPrice > nPrice THEN 
		RETURN aPrice;
	ELSE
		RETURN nPrice;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 函数:历史最低销售价
-- -----------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `uf_vendi_minPrice`;
DELIMITER ;;
CREATE FUNCTION `uf_vendi_minPrice`(
	gId bigint(20), -- 商品ID
	nPrice decimal(20,4)	-- 最新销售价
) RETURNS decimal(20,4) CHARSET utf8mb4
begin
	DECLARE aPrice DECIMAL(20,4);
	select MIN(a.salesPrice) into aPrice from `erp_vendi_detail` a where a.goodsId = gid; 
	IF aPrice < nPrice THEN 
		RETURN aPrice;
	ELSE
		RETURN nPrice;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- 存储过程:销售修改goods表的最新售价、最高价、最低价,goodsbook表的动态库存
-- -----------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `p_goodsbook_change_from_vendi`;
DELIMITER ;;
CREATE PROCEDURE `p_goodsbook_change_from_vendi`(
	gid bigint(20), -- 商品ID
	qty decimal(20,4), -- 进货数量
	nPrice decimal(20,4)	-- 最新售价
) 
begin
	DECLARE msg VARCHAR(100);
	IF EXISTS(SELECT 1 FROM erp_goodsbook a WHERE a.goodsId = gid) THEN 
		UPDATE erp_goodsbook a SET 
			a.dynamicQty = a.dynamicQty - qty, -- 动态库存
			a.changeDate = CURRENT_DATE() -- 修改日期
		WHERE a.goodsId = gid;
		IF ROW_COUNT() <> 1 THEN 
			SET msg = CONCAT('商品ID:',gid,' 未能成功更新最新库存、售价');
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg;
		END IF;
		UPDATE erp_goods b SET 
			b.price = uf_vendi_averagePrice(gid,nPrice,qty);
			b.newPrice = nPrice;
			b.minPrice = uf_vendi_minPrice(gid,nPrice);
			b.maxPrice = uf_vendi_maxPrice(gid,nPrice);
		WHERE b.id = gid;
		IF ROW_COUNT() <> 1 THEN 
			SET msg = CONCAT('商品ID:',gid,' 未能成功更新最新库存、售价');
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg;
		END IF;
	ELSE 
		SET msg = CONCAT('商品ID:',gid,' 没有新建库存表');
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- BEFORE INSERT (采购明细表插入)
-- -----------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_detail_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_detail` FOR EACH ROW begin
	IF EXISTS(select 1 from erp_purch_detail a where a.erp_purch_bil_id = new.erp_purch_bil_id and a.goodsId = new.goodsId) THEN 
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '同一张采购单不能添加相同商品!';
	END IF;
	IF new.qty * new.price > 0 THEN 
		set new.amt = new.qty * new.price;
	ELSE	
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '必须输入有效的商品数量或者价钱!';
	END IF;
	set new.createdDate = CURRENT_TIMESTAMP();
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- BEFORE UPDATE (采购明细表修改)
-- -----------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_detail_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_detail` FOR EACH ROW begin
	IF EXISTS(select 1 from erp_purch_detail a where a.erp_purch_bil_id = new.erp_purch_bil_id and a.goodsId = new.goodsId) THEN 
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '同一张采购单不能添加相同商品!';
	END IF;
	IF new.qty * new.price > 0 THEN 
		set new.amt = new.qty * new.price;
	ELSE	
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '必须输入有效的商品数量或者价钱!';
	END IF;
	set new.updatedDate = CURRENT_TIMESTAMP();
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- AFTER INSERT (采购单状态表)
-- -----------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bilwfw_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bilwfw_AFTER_INSERT` AFTER INSERT ON `erp_purch_bilwfw` FOR EACH ROW begin
	DECLARE iCount INT;
	DECLARE gId,sId BIGINT(20);
	DECLARE aPrice,aQty DECIMAL(20,4);
	SET iCount = (SELECT COUNT(1) FROM erp_purch_detail WHERE erp_purch_bil_id = new.billId);
	SET sId = (SELECT a.supplierId FROM erp_purch_bil a WHERE a.id = new.billId);
	IF new.billStatus = 'flowaway' THEN
		WHILE iCount > 0 THEN 
			SELECT a.price,a.qty,a.goodsId INTO aPrice,aQty,gId FROM erp_purch_detail a WHERE a.erp_purch_bil_id = new.billId LIMIT iCount-1,1;
			CALL p_goodsbook_change_from_purch(gId,aQty,sId,aPrice);
			SET iCount = iCount - 1;
		END WHILE;
	END IF;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- AFTER INSERT(采购进仓表)
-- -----------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_intoqty_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_intoqty_AFTER_INSERT` AFTER INSERT ON `erp_purch_bil_intoqty` FOR EACH ROW begin
	DECLARE aSnCode,aExchangeCode VARCHAR(100);
	DECLARE iCount DECIMAL(20,4);
	set aSncode = uf_erp_purch_bil_intosnc_getMaxSnCode(new.goodsId);
	set aExchangeCode = uf_erp_goods_getExchangeCode(new.goodsId);
	set iCount = new.qty;
	WHILE iCount > 0 DO
		-- 进仓二维码
		INSERT INTO erp_purch_bil_intosnc (erp_purch_bil_id,goodsId,roomId,shelfId,ers_packageattr_id,snCode)
		VALUES (new.erp_purch_bil_id,new.goodsId,new.roomId,new.shelfId,new.ers_packageattr_id,
						CONCAT(DATE_FORMAT(NOW(),'%Y%m%d'),aSnCode,aExchangeCode));
		-- 商品二维码
		INSERT INTO erp_goods_storesnc (goodsId,roomId,shelfId,ers_packageattr_id,snCode) 
		VALUES (new.goodsId,new.roomId,new.shelfId,new.ers_packageattr_id,
						CONCAT(DATE_FORMAT(NOW(),'%Y%m%d'),aSnCode,aExchangeCode));
		set aSnCode = LPAD(snCode+1,6,0), iCount = iCount - 1;
	END WHILE;
	-- 商品存放
	UPDATE erp_goods_storeqty a SET 
		a.qty = a.qty + new.qty;
	WHERE a.goodsId = new.goodsId 
		AND a.roomId = new.roomId 
		AND a.shelfId = new.shelfId 
		AND a.ers_packageattr_id = new.ers_packageattr_id;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- AFTER INSERT(进仓单状态表)修改静态库存,名字未改(于此表加个erp_purch_bil_id字段?)
-- -----------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_into_wfw_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_into_wfw_AFTER_INSERT` AFTER INSERT ON `erp_purch_bil_into_wfw` FOR EACH ROW begin
	DECLARE iCount INT;
	DECLARE gid BIGINT(20);
	DECLARE aQty DECIMAL(20,4);
	SELECT COUNT(1) INTO iCount FROM erp_purch_bil_intoqty WHERE a.erp_purch_bil_id = new.erp_purch_bil_id;
	WHILE iCount > 0 THEN 
		SELECT a.goodsId,a.qty INTO gid,aQty FROM erp_purch_bil_intoqty a WHERE a.erp_purch_bil_id = new.erp_purch_bil_id LIMIT iCount-1,1;
		UPDATE erp_goodsbook b SET b.staticQty = b.staticQty + aQty WHERE b.goodsId = gid;
		SET iCount = iCount - 1;
	END WHILE;
end
;;
DELIMITER ;

-- -----------------------------------------------------------------------------------
-- AFTER INSERT(出仓单状态表)修改静态库存,名字未改(于此表加个erp_vendi_bil_id字段?)
-- -----------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_gout_wfw_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_gout_wfw_AFTER_INSERT` AFTER INSERT ON `erp_vendi_bil_gout_wfw` FOR EACH ROW begin
	DECLARE iCount INT;
	DECLARE gid BIGINT(20);
	DECLARE aQty DECIMAL(20,4);
	SELECT COUNT(1) INTO iCount FROM erp_purch_bil_intoqty WHERE a.erp_purch_bil_id = new.erp_purch_bil_id;
	WHILE iCount > 0 THEN 
		SELECT a.goodsId,a.qty INTO gid,aQty FROM erp_purch_bil_intoqty a WHERE a.erp_purch_bil_id = new.erp_purch_bil_id LIMIT iCount-1,1;
		UPDATE erp_goodsbook b SET 
			b.staticQty = b.staticQty + aQty 
			b.changeDate = CURRENT_DATE();
		WHERE b.goodsId = gid;
		SET iCount = iCount - 1;
	END WHILE;
end
;;
DELIMITER ;