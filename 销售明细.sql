DROP TRIGGER IF EXISTS `tr_erp_sales_detail_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_sales_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_sales_detail` FOR EACH ROW BEGIN
	DECLARE msg varchar(1000);
	DECLARE aid, aGoodsId, asupplierId BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE aQty, aDegree int;
	DECLARE aPrice DECIMAL(20,4);
	DECLARE aPackageUnit varchar(100);
	DECLARE aSubmit, aCheck, aCost TINYINT;
	DECLARE oTime datetime;
	
	set msg = concat('追加销售单（编号：', new.erp_vendi_bil_id, ', ）明细');
	SELECT a.isCheck, a.isSubmit, a.outTime, a.isCost
	INTO aCheck, aSubmit, oTime, aCost
	FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id;
	if aCost > 0 THEN
		set msg = concat(msg, '已收款，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif oTime > 0 THEN
		set msg = concat(msg, '已出仓，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSubmit > -1 THEN 
		set msg = concat(msg, '已进入出仓流程，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	IF isnull(new.erp_vendi_detail_id) OR (new.erp_vendi_detail_id = 0) THEN  -- 不是询价明细转过来的销售明细
		if isnull(new.ers_packageAttr_id) or new.ers_packageAttr_id = 0 THEN
			set msg = concat(msg, '必须指定有效的包装！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif new.packageQty < 1 or isnull(new.packageQty)then
			set msg = concat(msg, '必须指定有效的数量！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif new.salesPackagePrice < 1 or isnull(new.salesPackagePrice) THEN
			set msg = concat(msg, '必须指定有效的售价！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif isnull(new.lastModifiedId) or new.lastModifiedId = 0 then
			set msg = concat(msg, '必须指定有效的创建人！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
			-- 最后修改用户变更，获取相关信息
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
		-- 获取包装的相关信息
		select a.actualQty, a.goodsId, a.packageUnit, a.newPrice, a.newSupplierId into aQty, aGoodsId, aPackageUnit, aPrice, asupplierId
		from ers_packageattr a where a.id = new.ers_packageattr_id;
		if isnull(aQty) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售明细，必须指定包装';
		elseif isnull(new.price) then
			if exists(select 1 from erp_goodsbook g where g.goodsId = aGoodsId and g.dynamicQty < new.qty) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售明细, 库存不足且没有最新供应商，无法自动生成采购订单，不能直接销售！';
				set new.isEnough = 0;	-- 先将明细改成库存不足
			ELSE
				set new.isEnough = 1;
			end if;
		end if;
		-- 需要进行售价有效性检查
		if uf_salesPrice_isValiad(new.goodsId, new.packagePrice, new.salesPackagePrice) = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '商品售价不符合调价规则！';
		end if;

		-- 最新进货价并计算进货金额、售价、销售金额
		set new.goodsId = aGoosId, new.supplierId = asupplierId
			, new.packageUnit = aPackageUnit, new.qty = aQty * new.packageQty
			, new.packagePrice = aPrice
			, new.createdDate = CURRENT_TIMESTAMP, new.lastModifiedDate = CURRENT_TIMESTAMP();
		set new.amt = new.packagePrice * new.packageQty, new.price = new.packagePrice/aQty
			, new.salesAmt = new.packageQty * new.salesPackagePrice, new.salesPrice = new.salesPackagePrice/aQty; 
	end if;
END;;
DELIMITER ;