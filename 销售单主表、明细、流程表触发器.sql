-- *****************************************************************************************************
-- 创建存储过程 p_vendi_purch, 销售单生成采购单、明细
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_vendi_purch`;
DELIMITER ;;
CREATE PROCEDURE `p_vendi_purch`(
	aid	-- erp_vendi_bil.id 销售单id
)
BEGIN
			INSERT INTO erp_purch_bil( erp_vendi_bil_id, supplierId, creatorId, createdDate
				, createdBy, empId, empName, memo
				, lastModifiedDate, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy)
			SELECT DISTINCT a.id, b.supplierId, a.checkUserId, now()
				, a.lastModifiedBy, a.checkEmpId, a.checkEmpName, concat('销售订单审核库存不足自动转入。')
				, now(), a.lastModifiedId, a.lastModifiedEmpId, a.lastModifiedEmpName, a.lastModifiedBy
			FROM erp_vendi_bil a 
			INNER JOIN erp_sales_detail b ON b.erp_vendi_bil_id = a.id 
			where a.id = aid AND b.isEnough = 0
			;

			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成采购订单主表!';
			end if;
			
			-- 生成采购订单明细
			insert into erp_purch_detail(erp_purch_bil_id, erp_vendi_bil_id, erp_sales_detail_id
				, goodsId, ers_packageAttr_id, packageUnit, packageQty, packagePrice
				, qty, price, amt, createdDate, updatedDate, lastModifiedDate
				, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy)
			select b.id, b.erp_vendi_bil_id, a.id
				, a.goodsId, a.ers_packageAttr_id, a.packageUnit, a.packageQty, a.packagePrice
				, a.qty, a.price, a.amt, now(), now(), now()
				, b.lastModifiedId, b.lastModifiedEmpId, b.lastModifiedEmpName, a.lastModifiedBy
			from erp_sales_detail a 
			INNER JOIN erp_purch_bil b on a.erp_vendi_bil_id = b.erp_vendi_bil_id and a.supplierId = b.supplierId
			where a.erp_vendi_bil_id = aid and a.isEnough = 0 
			;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '生成采购明细时出错！';
			end if;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
-- 销售单主表
-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_bil` FOR EACH ROW
BEGIN
	DECLARE aName, aUserName varchar(100);

	if exists(select 1 from autopart01_crm.`erc$customer` a where a.id = new.customerId limit 1) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$customer` a where a.id = new.customerId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单，必须指定有效的客户！';
	end if;
	
	IF isnull(new.creatorId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单，必须指定创建人！';
	END IF;

	if new.erc$telgeo_contact_id > 0 THEN
		if exists(select 1 from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id) then
			-- 生成发货地址文本
			set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
				from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
			);
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单时，发货地址和电话无效！';
		end if;
	end if;

	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_vendi_bil a 
				where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);
	
	SET new.isCheck = 0, new.isSubmit = 0;

END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_AFTER_INSERT` AFTER INSERT ON `erp_vendi_bil` FOR EACH ROW 
BEGIN
	-- 写入销售单流程状态表
	if new.erp_inquiry_bil_id > 0 then  -- 询价单转过来的销售单
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name, memo)
		select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy, '刚刚创建',
			, concat('询价单（编号：', new.erp_inquiry_bil_id, '）转入。');
	else
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name, memo)
		select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy, '刚刚创建',
			, concat('员工（编号：', new.empId, ' 姓名：', new.empName, '）创建。');
	end if;
	-- 生成销售发货单
	insert into erp_vendi_deliv(erp_vendi_bil_id, userId, empId, empName, opTime, erc$telgeo_contact_id)
	select new.id, new.creatorId, new.empId, new.empName, CURRENT_TIMESTAMP(), new.erc$telgeo_contact_id;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_bil` FOR EACH ROW 
BEGIN
	DECLARE aid BIGINT(20);
	
	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;
	
	-- 审核人
	IF ISNULL(old.checkUserId) AND new.checkUserId > 0 THEN	
		SET new.checkEmpId = new.lastModifiedEmpId, new.checkEmpName = new.lastModifiedEmpName;
	END IF;

	IF old.isCheck = 0 AND new.isCheck = 1 THEN -- 提交待审
		IF ISNULL(erc$telgeo_contact_id) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '提交待审时，必须指定收货地址！';
		ELSEIF new.lastModifiedId <> new.creatorId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单只能由客服提交待审！';
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单提交审核时不能变更客户！！';
		END IF;
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'submitthatview', new.creatorId, new.empId, new.empName, new.createdBy, '提交待审';

	ELSEIF old.isCheck = 1 AND new.isCheck = 0 THEN	-- 审核不通过
		IF new.lastModifiedId IN (new.creatorId) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单不能由客服审核退回！';
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单审核退回时不能变更客户！！';
		END IF;
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'submitBack', new.creatorId, new.empId, new.empName, new.createdBy, '审核退回';

	ELSEIF old.isCheck = 1 AND new.isCheck = 2 THEN	-- 审核通过
		IF new.lastModifiedId IN (new.creatorId) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单不能由客服审核通过！';
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单审核通过时不能变更客户！！';
		END IF;
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'checked', new.creatorId, new.empId, new.empName, new.createdBy, '审核通过';

	ELSEIF old.isSubmit = 0 AND new.isSubmit = 1 THEN -- 提交出仓申请
		IF new.isCheck <> 2 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售单没有审核通过，不能提交出仓申请！';
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单提交出仓申请时不能变更客户！！'; 
		END IF;
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'outapply', new.creatorId, new.empId, new.empName, new.createdBy, '出仓申请';

	END IF;

	IF ISNULL(old.costTime) AND EXISTS(new.costTime) THEN
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'cost', new.creatorId, new.empId, new.empName, new.createdBy, '客户付款';
	ELSEIF ISNULL(old.outTime) AND EXISTS(new.outTime) THEN
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'out', new.creatorId, new.empId, new.empName, new.createdBy, '商品出仓';
	END IF;

	-- 记录操作
	insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.id, 'selfupdated', new.creatorId, new.empId, new.empName, new.createdBy, '自行修改';

	-- 最新操作时间
	SET new.lastModifiedDate = CURRENT_TIMESTAMP();

END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_AFTER_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_AFTER_UPDATE` AFTER UPDATE ON `erp_vendi_bil` FOR EACH ROW 
BEGIN
	IF old.isCheck = 1 AND new.isCheck = 2 THEN
		if exists(select 1 from erp_sales_detail b INNER JOIN erp_goodsbook g on b.goodsId = g.goodsId
			where b.erp_vendi_bil_id = new.billId and g.dynamicQty < b.qty  limit 1
		) THEN  -- 库存不足， 生成采购订单
			-- 先将明细改成库存不足
			update erp_sales_detail b INNER JOIN erp_goodsBook g on b.goodsId = g.goodsId
				set b.isEnough = (case when g.dynamicQty < b.qty then 0 else 1 end)
				where b.erp_vendi_bil_id = new.id;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改是否可以出仓标志!';
			end if;
			-- 生成采购订单和明细
			CALL p_vendi_purch(new.id);

		else	-- 库存足够， 修改状态为可以出库
			IF EXISTS(SELECT 1 FROM erp_sales_detail b where b.erp_vendi_bil_id = new.id and b.isEnough = 0 limit 1) THEN
				update erp_sales_detail b set b.isEnough = 1 
				where b.erp_vendi_bil_id = new.id and b.isEnough = 0;
				if ROW_COUNT() = 0 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改是否可以出仓标志!';
				end if;
			END IF;
		end if;
	END IF;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_BEFORE_DELETE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_bil` FOR EACH ROW 
BEGIN
	IF old.isCheck = 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单已提交待审，不能删除！';
	ELSEIF old.isCheck = 2 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单已审核通过，不能删除！';
	ELSEIF old.isSubmit = 1 THEN 
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售单已提交出仓申请，不能删除！';
	END IF;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
-- 销售明细表(写到这里)
-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_sales_detail_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_sales_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_sales_detail` FOR EACH ROW
BEGIN
	DECLARE msg varchar(1000);
	DECLARE aSubmit, aCheck TINYINT;
	
	set msg = concat('销售单（编号：', new.erp_vendi_bil_id, ', ）');
	SELECT a.isCheck,a.isSubmit INTO aCheck,aSubmit FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id;
	IF aCheck = 1 THEN
		set msg = concat(msg, '已提交待审，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck = 2 THEN
		set msg = concat(msg, '已通过审核，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSubmit = 1 THEN
		set msg = concat(msg, '已提交出仓申请，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	IF isnull(new.erp_vendi_detail_id) OR (new.erp_vendi_detail_id = 0) THEN  -- 不是询价明细转过来的销售明细
		if new.packageQty <= 0 then
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的数量，无法新增！';
		elseif new.salesPackagePrice <= 0 THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未指定正确的售价，无法新增！';
		elseif isnull(new.lastModifiedId) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售明细，必须指定有效的创建人！';
		end if;
		
	END IF;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
-- 销售单流程表
-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_bilwfw_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_bilwfw` FOR EACH ROW 
BEGIN
	set new.opTime = now();
	IF ISNULL(new.memo) THEN 
		SET new.memo = concat('员工（编号：', new.empId, ' 姓名：', new.empName, '）销售单（编号：', new.billId,'）', new.name);
	END IF;
END;;
DELIMITER ;