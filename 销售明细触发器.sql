DROP TRIGGER IF EXISTS `tr_erp_sales_detail_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_sales_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_sales_detail` FOR EACH ROW BEGIN
	DECLARE aid, aGoodsId, asupplierId BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE aQty, aDegree int;
	DECLARE aPrice DECIMAL(20,4);
	DECLARE aPackageUnit varchar(100);
	DECLARE aSubmit, aCheck, aCost TINYINT;
	DECLARE oTime datetime;
	DECLARE msg varchar(1000);

	set msg = concat('销售单（编号：', new.erp_vendi_bil_id, ', ）明细（编号：', new.id,'），');

	-- 获取销售订单主表信息
	SELECT a.isCheck, a.isSubmit, a.outTime , a.isCost
	INTO aCheck, aSubmit, oTime, aCost 
	FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id;

	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;
	
	IF new.outTime > 0 AND ISNULL(old.outTime) THEN
		-- 记录操作
		insert into erp_vendi_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
			SELECT new.erp_vendi_bil_id, 'out', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('明细（编号：', new.id, '）配件出仓完毕！');
	ELSEIF new.stockTime > 0 AND ISNULL(old.stockTime) THEN
		-- 记录操作
		insert into erp_vendi_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
			SELECT new.erp_vendi_bil_id, 'stock', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('明细（编号：', new.id, '）配件备货完毕！');
	ELSEIF new.isEnough = 1 AND old.isEnough = 0 THEN
		-- 记录操作
		insert into erp_vendi_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
			SELECT new.erp_vendi_bil_id, 'changeEnough', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('修改明细（编号：', new.id, '）标志为可以出仓！');
	ELSE

		-- 根据主表状态判断是否可以修改
		if aCost > 0 THEN
			set msg = concat(msg, '已收款，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif oTime > 0 THEN
			set msg = concat(msg, '已出仓，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aSubmit > -1 THEN 
			set msg = concat(msg, '已进入出仓流程，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aCheck > -1 THEN
			set msg = concat(msg, '已进入提交待审或审核通过，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif isnull(new.ers_packageAttr_id) or new.ers_packageAttr_id = 0 THEN
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
		end if;

		-- 生成提货地址
		if new.erc$telgeo_contact_id > 0 and isnull(new.takeGeoTel) 
					and (isnull(old.erc$telgeo_contact_id) or new.erc$telgeo_contact_id <> old.erc$telgeo_contact_id) then
			set new.takeGeoTel = (select CONCAT('联系人:', IFNULL(a.person, ''), '  联系号码:', IFNULL(a.callnum, ''), '  地址:', IFNULL(a.addrroad, ''))
					from autopart01_crm.erc_supplier_address a where a.id = new.erc$telgeo_contact_id
			);
		end if;
	
		if new.erp_vendi_detail_id > 0 THEN
			if new.ers_packageAttr_id <> old.ers_packageAttr_id then
				set msg = concat(msg, '该单据从询价单转入，不能修改包装！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			elseif new.packageQty <> old.packageQty then
				set msg = concat(msg, '该单据从询价单转入，不能修改数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
		end if;

		select a.actualQty, a.goodsId, a.packageUnit, a.newPrice, a.newSupplierId into aQty, aGoodsId, aPackageUnit, aPrice, asupplierId
		from ers_packageattr a where a.id = new.ers_packageattr_id;
		if isnull(aQty) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改销售明细，必须指定有效的包装';
		elseif old.goodsId <> aGoodsId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改销售明细，不能变更配件！';
		end if;

		set new.qty = aQty * new.packageQty;
		if exists(select 1 from erp_goodsbook g where g.goodsId = aGoodsId and g.staticQty < new.qty) THEN
			IF isnull(aPrice) THEN
-- 				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改销售明细, 库存不足且没有最新供应商，无法自动生成采购订单，不能直接销售！';
				UPDATE ers_packageattr a 
				SET a.newPrice = new.price, a.newSupplierId = new.supplierId, a.minPrice = new.price, a.maxPrice = new.price
				WHERE a.id = new.ers_packageattr_id;
			end if;
			set new.isEnough = 0;	-- 先将明细改成库存不足
		ELSE
			set new.isEnough = 1;
		end if;
		IF new.ers_packageAttr_id <> old.ers_packageAttr_id THEN
			-- 最新进货价并计算进货单价及包装相关信息
			set new.packageUnit = aPackageUnit, new.supplierId = asupplierId, new.goodsId = aGoodsId, new.packagePrice = aPrice;
		end if;
		if new.salesPackagePrice > 0 and (isnull(old.salesPackagePrice) or new.salesPackagePrice <> old.salesPackagePrice) then
			-- 如果修改了售价，需要进行售价有效性检查
			if uf_salesPrice_isValiad(new.goodsId, new.packagePrice, new.salesPackagePrice) = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '商品售价不符合调价规则！';
			end if;
		end if;
		-- 计算销售金额及进货金额
		set new.lastModifiedDate = CURRENT_TIMESTAMP();
		if new.packagePrice > 0 then 
			set new.amt = new.packagePrice * new.packageQty, new.price = new.packagePrice/aQty; 
		end if;
		if new.salesPackagePrice > 0 then 
			set new.salesAmt = new.packageQty * new.salesPackagePrice, new.salesPrice = new.salesPackagePrice/aQty; 
		end if;

		-- 记录操作记录
		insert into erp_vendi_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
		SELECT new.erp_vendi_bil_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, '自行修改销售单明细';
	END IF;
end;;
DELIMITER ;