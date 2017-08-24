SET FOREIGN_KEY_CHECKS =0;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	订单变更单主表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_change;
CREATE TABLE `erp_vendi_change` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '是否提交审核。-1：可以更改；0：提交待审，客服不能更改 1：审核通过，不能更改',
  `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '来源单编码，销售订单ID',
  `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '询价单ID 冗余',
  `customerId` bigint(20) NOT NULL COMMENT '客户ID',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新操作用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新操作员工ID',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `costUserId` bigint(20) DEFAULT NULL COMMENT '退款用户确认ID',
  `costEmpId` bigint(20) DEFAULT NULL COMMENT '退款员工确认ID',
	`erp_payment_type_id` int(11) DEFAULT NULL COMMENT '支付方式ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '初建员工姓名',
  `createdBy` varchar(255) DEFAULT NULL COMMENT '初建登录账户名称',
  `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新操作员工姓名',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新操作登录账户名称',
  `checkEmpName` varchar(100) DEFAULT NULL COMMENT '审核员工姓名，跟单审核',
  `costEmpName` varchar(100) DEFAULT NULL COMMENT '退款员工姓名，出纳退款',
  `zoneNum` varchar(30) DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
  `code` varchar(100) NOT NULL COMMENT '订单变更单单号 新增时触发器生成',
	`inquiryCode` varchar(100) DEFAULT NULL COMMENT '询价单号 新增时触发器生成，冗余',
  `payAccount` varchar(100) DEFAULT NULL COMMENT '客户收款账号，出纳退款',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `costTime` datetime DEFAULT NULL COMMENT '退款时间',
  `priceSumSell` decimal(20,4) DEFAULT '0' COMMENT '售价金额总计，退货金额',
  `reason` varchar(255) DEFAULT NULL COMMENT '订单变更原因',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erp_vendi_change_code_idx` (`code`) USING BTREE,
	KEY `erp_vendi_change_inquiryCode_idx` (`inquiryCode`) USING BTREE,
  KEY `erp_vendi_change_creatorId_idx` (`creatorId`) USING BTREE,
  KEY `erp_vendi_change_customerId_idx` (`customerId`) USING BTREE,
  KEY `erp_vendi_change_erp_inquiry_bil_id` (`erp_inquiry_bil_id`) USING BTREE,
  KEY `erp_vendi_change_erp_vendi_bil_id` (`erp_vendi_bil_id`) USING BTREE,
  CONSTRAINT `fk_erp_vendi_change_erp_vendi_bil_id` FOREIGN KEY (`erp_vendi_bil_id`) 
		REFERENCES `erp_vendi_bil` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_vendi_change_erp_payment_type_id` FOREIGN KEY (`erp_payment_type_id`) 
		REFERENCES `erp_payment_type` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单变更单主表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_change` FOR EACH ROW BEGIN
	DECLARE aid, aCustomerId, aInquiryId BIGINT(20);
	DECLARE aName, aUserName, aZoneNum, aInquiryCode varchar(100);
	DECLARE aPriceSumSell DECIMAL(20,4);
	DECLARE aTakeGeoTel VARCHAR(1000);

	-- 新增订单变更单时必须指定原因
	IF ISNULL(new.reason) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增配件核销单，必须指定核销原因！';
	END IF;

	-- 获取销售订单信息
	IF EXISTS(SELECT 1 FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id) THEN
		SELECT a.erp_inquiry_bil_id, a.customerId, a.zoneNum, a.priceSumSell, a.inquiryCode
		INTO aInquiryId, aCustomerId, aZoneNum, aPriceSumSell, aInquiryCode
		FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增订单变更单时，必须选择有效销售订单', MYSQL_ERRNO = 1001;
	END IF;
	
	-- 判断销售退货单客户是否与销售单客户匹配
	IF aCustomerId <> new.customerId THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单变更单与销售单的客户不匹配',MYSQL_ERRNO = 1001;
	ELSEIF aPriceSumSell < new.priceSumSell THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单变更单总金额不能大于销售总金额',MYSQL_ERRNO = 1001;
	END IF;

	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) OR new.lastModifiedId < 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建订单变更单，必须指定有效用户！';
	elseif isnull(new.lastModifiedEmpId) then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName,
				new.creatorId = new.lastModifiedId, new.empId = aid, new.empName = aName, new.createdBy = aUserName;
	end if;

	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(IFNULL(new.zoneNum, ''), date_format(NOW(),'%Y%m%d'), LPAD(new.lastModifiedId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_vendi_change a 
				where date(a.createdDate) = date(NOW()) and a.creatorId = new.lastModifiedId), 0
			) + 1, 4, 0)
	);

	-- 根据选取的销售订单自动写入相关信息
	SET new.erp_inquiry_bil_id = aInquiryId, new.zoneNum = aZoneNum, new.createdDate = NOW(), new.lastModifiedDate = NOW()
		,new.inquiryCode = aInquiryCode;

	IF ISNULL(new.isCheck) THEN
		SET new.isCheck = -1;
	END IF;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_AFTER_INSERT` AFTER INSERT ON `erp_vendi_change` FOR EACH ROW BEGIN
	-- 写入订单变更流程状态表
	insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy
				, CONCAT('刚刚创建，对应销售订单（编号：', new.erp_vendi_bil_id, '）');
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_change` FOR EACH ROW BEGIN
	declare aid bigint(20);
	DECLARE aName, aUserName varchar(100);
	
	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;

	IF ISNULL(old.costUserId) AND new.costUserId > 0 THEN -- 退款确认
		IF new.isCheck <> 1 THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有审核通过，不能确认退款！', MYSQL_ERRNO = 1001;
		ELSEIF new.costUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时，最新修改员工必须与退款确认员工相同！', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时不能变更客户收款账号！！';
		END IF;
		-- 记录退款确认人，确认时间
		set new.costEmpId = aid, new.costEmpName = aName, new.costTime = NOW();

		insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'cost', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '退款确认';
	ELSEIF old.isCheck = 0 AND new.isCheck = 1 THEN -- 审核通过(待定)
		IF new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '通过审核时，最新修改员工必须与审核员工相同！', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '通过审核时不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核通过时不能变更客户收款账号！！';
		END IF;
		-- 记录审核人，审核时间
		set new.checkEmpId = aid, new.checkEmpName = aName, new.checkTime = NOW();

		-- 修改配件账簿动态库存
			update erp_goodsbook a INNER JOIN erp_vendi_change_detail b on b.goodsId = a.goodsId and b.erp_vendi_change_id = new.id
			set a.dynamicQty = a.dynamicQty + b.qty, a.changeDate = CURDATE();
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改账簿动态库存！';
			end if;
			-- 修改日记账账簿销售动态库存
			update erp_goods_jz_day a INNER JOIN erp_vendi_change_detail b on b.goodsId = a.goodsId and b.erp_vendi_change_id = new.id
			set a.salesChangeDynaimicQty = a.salesChangeDynaimicQty + b.qty
			where a.datee = CURDATE();
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改日记账账簿动态库存！';
			end if;

		insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核通过';
	ELSEIF old.isCheck = 0 AND new.isCheck = -1 THEN -- 审核不通过
		IF ISNULL(new.memo) OR new.memo = '' THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时，必须在备注栏指定不通过原因！！', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时不能变更客户收款账号！！';
		END IF;
		insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name, said)
		select new.id, 'checkedBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核不通过', CONCAT(' （原因：', IFNULL(new.memo, ' '), '）');
	ELSEIF old.isCheck = -1 AND new.isCheck = 0 THEN -- 提交待审
		IF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '提交待审时不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '提交待审时不能变更客户收款账号！！';
		END IF;
		insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'submitCheck', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '提交待审';
	ELSE
		-- 记录修改操作
		insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '修改订单变更单主表';
	END IF;

	IF new.erp_vendi_bil_id <> old.erp_vendi_bil_id THEN
		SET new.erp_inquiry_bil_id = (SELECT a.erp_inquiry_bil_id FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id);
	END IF;
             
	set new.lastModifiedDate = CURRENT_TIMESTAMP();

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_change` FOR EACH ROW BEGIN
	IF old.costTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单变更单已退款，不能删除！';
	ELSEIF old.isCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单变更单已提交待审或审核通过，不能删除！';
	END IF;
	delete a from erp_vendi_change_detail a where a.erp_vendi_change_id = old.id;
	insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select old.id, 'selfupdated', old.lastModifiedId, old.lastModifiedEmpId, old.lastModifiedEmpName, old.lastModifiedBy
				, '删除订单变更单主表';
END;;
DELIMITER ;


-- 	--------------------------------------------------------------------------------------------------------------------
-- 	订单变更明细表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_change_detail;
CREATE TABLE `erp_vendi_change_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_change_id` bigint(20) NOT NULL COMMENT '订单变更单主表ID',
  `erp_sales_detail_id` bigint(20) DEFAULT NULL COMMENT '销售明细ID',
  `ers_packageAttr_id` bigint(20) DEFAULT NULL COMMENT '商品的包装ID  最低一级的包裹名称即单品的计量单位',
  `goodsId` bigint(20) DEFAULT NULL COMMENT '配件 冗余字段 = ers_packageattr.goodsId',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID',
  `packageQty` int(11) DEFAULT '0' COMMENT '包装数量',
  `qty` int(11) DEFAULT '0' COMMENT '实际单品数量 最低一级包装直接等于packageQty',
  `packageUnit` varchar(30) DEFAULT NULL COMMENT '包裹单位 冗余字段，触发器取ers_packageattr.packageUnit',
  `salesPackagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装售价 前台初始化取 ers_packageattr.newSalesPrice',
  `salesPrice` decimal(20,4) DEFAULT NULL COMMENT '单品售价',
  `salesAmt` decimal(20,4) DEFAULT NULL COMMENT '销售金额 = packageQty * salesPackagePrice',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间；--@CreatedDate',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间；--@LastModifiedDate',
  `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(100) DEFAULT NULL COMMENT '最新修改人员；--@LastModifiedBy',
  `reason` varchar(255) DEFAULT NULL COMMENT '订单变更原因',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_vendi_change_detail_erp_vendi_change_id_idx` (`erp_vendi_change_id`,`goodsId`) USING BTREE,
  KEY `erp_vendi_change_detail_goodsId_idx` (`goodsId`) USING BTREE,
  KEY `erp_vendi_change_detail_erp_sales_detail_id_idx` (`erp_sales_detail_id`) USING BTREE,
  KEY `erp_vendi_change_detail_ers_packageAttr_id_idx` (`ers_packageAttr_id`) USING BTREE,
  CONSTRAINT `fk_erp_vendi_change_detail_erp_goods_id` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_vendi_change_detail_erp_vendi_change_id` FOREIGN KEY (`erp_vendi_change_id`) 
		REFERENCES `erp_vendi_change` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_vendi_change_detail_ers_packageAttr_id` FOREIGN KEY (`ers_packageAttr_id`) 
		REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单变更单明细'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_change_detail` FOR EACH ROW BEGIN
	DECLARE msg varchar(1000);
	DECLARE aid, aGoodsId BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE aPackageQty, aQty, bQty int;
	DECLARE aSPackagePrice, aSPrice DECIMAL(20,4);
	DECLARE aPackageUnit varchar(100);
	DECLARE aCheck TINYINT;
	DECLARE cTime datetime;
	
	set msg = concat('追加订单变更单（编号：', new.erp_vendi_change_id, ', ）明细');
	
	SELECT a.isCheck, a.costTime INTO aCheck, cTime
	FROM erp_vendi_change a WHERE a.id = new.erp_vendi_change_id;

	if cTime > 0 THEN
		set msg = concat(msg, '已退款，不能追加变更配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取销售明细配件等相关信息
	SELECT a.goodsId, a.packageQty, a.qty, a.packageUnit, a.salesPackagePrice, a.salesPrice
	INTO aGoodsId, aPackageQty, aQty, aPackageUnit, aSPackagePrice, aSPrice
	FROM erp_sales_detail a WHERE a.id = new.erp_sales_detail_id;

	IF isnull(new.ers_packageAttr_id) OR new.ers_packageAttr_id = 0 THEN
		SET msg = concat(msg, '必须指定有效的包装！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF new.packageQty < 1 OR isnull(new.packageQty) THEN
		SET msg = concat(msg, '必须指定有效的数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.lastModifiedId) OR new.lastModifiedId = 0 THEN
		SET msg = concat(msg, '必须指定有效的创建人！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	SELECT a.actualQty INTO bQty FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;

	-- 最后修改用户变更
	call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
	set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	-- 设置相关信息
	SET new.goodsId = aGoodsId, new.createdDate = NOW(),new.lastModifiedDate  = NOW();
	SET new.salesPackagePrice = aSPackagePrice, new.salesPrice = aSPrice, new.salesAmt = aSPackagePrice * new.packageQty;
	SET new.qty = bQty * new.packageQty, new.packageUnit = aPackageUnit;

	IF new.qty > aQty THEN
		SET msg = concat(msg, '配件变更数量不能大于销售数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

END;;
DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_detail_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_detail_AFTER_INSERT` AFTER INSERT ON `erp_vendi_change_detail` FOR EACH ROW BEGIN
	-- 插入流程表
	insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_vendi_change_id, 'append', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '追加变更明细';
end;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_change_detail` FOR EACH ROW BEGIN
	DECLARE msg varchar(1000);
	DECLARE aid, aGoodsId BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE aPackageQty, aQty, bQty int;
	DECLARE aSPackagePrice, aSPrice DECIMAL(20,4);
	DECLARE aPackageUnit varchar(100);
	DECLARE aCheck TINYINT;
	DECLARE cTime datetime;

	set msg = concat('订单变更单（编号：', new.erp_vendi_change_id, ', ）明细');

	-- 获取主表相关信息
	SELECT a.isCheck, a.costTime INTO aCheck, cTime
	FROM erp_vendi_change a WHERE a.id = new.erp_vendi_change_id;

	-- 获取销售明细配件等相关信息
	SELECT a.goodsId, a.packageQty, a.qty, a.salesPackagePrice, a.salesPrice
	INTO aGoodsId, aPackageQty, aQty, aSPackagePrice, aSPrice
	FROM erp_sales_detail a WHERE a.id = new.erp_sales_detail_id;

	IF cTime > 0 THEN
		set msg = concat(msg, '已退款，不能修改！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能修改！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.ers_packageAttr_id) OR new.ers_packageAttr_id = 0 THEN
		SET msg = concat(msg, '必须指定有效的包装！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF new.packageQty < 1 OR isnull(new.packageQty) THEN
		SET msg = concat(msg, '必须指定有效的数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.lastModifiedId) or new.lastModifiedId = 0 THEN
		SET msg = concat(msg, '必须指定有效的修改员工！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	IF new.erp_sales_detail_id <> old.erp_sales_detail_id THEN
		
		SELECT a.actualQty, a.packageUnit INTO bQty, aPackageUnit FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;

		SET new.goodsId = aGoodsId, new.qty = bQty * new.packageQty, new.packageUnit = aPackageUnit;
		SET new.salesPackagePrice = aSPackagePrice, new.salesPrice = aSPrice, new.salesAmt = aSPackagePrice * new.packageQty;
	ELSEIF new.ers_packageAttr_id <> old.ers_packageAttr_id or new.packageQty <> old.packageQty THEN
		SELECT a.actualQty, a.packageUnit INTO bQty, aPackageUnit FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
		SET new.salesAmt = aSPackagePrice * new.packageQty, new.qty = packageQty * bQty, new.packageUnit = aPackageUnit;
	END IF;

	IF new.qty > bQty THEN
		SET msg = concat(msg, '配件变更数量不能大于销售数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 最后修改用户变更，获取相关信息
	IF new.lastModifiedId <> old.lastModifiedId THEN
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	END IF;

	-- 记录操作记录
	insert into erp_vendi_change_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.erp_vendi_change_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
				, new.lastModifiedBy, '自行修改订单变更单明细';
            
	set new.lastModifiedDate = CURRENT_TIMESTAMP();

end;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_change_detail` FOR EACH ROW BEGIN
	DECLARE aCheck TINYINT;
	DECLARE cTime datetime;
	DECLARE msg VARCHAR(1000);

	set msg = concat('销售退货单（编号：', old.erp_vendi_change_id, ', ）明细');
	SELECT a.isCheck, a.costTime INTO aCheck, cTime
	FROM erp_vendi_change a WHERE a.id = old.erp_vendi_change_id;
	
	IF cTime > 0 THEN
		set msg = concat(msg, '已退款，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

END;;
DELIMITER ;


-- 	--------------------------------------------------------------------------------------------------------------------
-- 	订单变更状态表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_change_bilwfw;
CREATE TABLE `erp_vendi_change_bilwfw` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billId` bigint(20) DEFAULT NULL COMMENT '单码',
  `billStatus` varchar(50) NOT NULL COMMENT '单状态',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `userName` varchar(100) DEFAULT NULL COMMENT '登陆用户名',
  `name` varchar(255) NOT NULL COMMENT '步骤名称',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
  `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
  PRIMARY KEY (`id`),
  KEY `userId_idx` (`userId`),
  KEY `billStatus_idx` (`billStatus`),
  KEY `opTime_idx` (`opTime`),
  KEY `erp_vendi_change_bilwfw_billId_idx` (`billId`),
  CONSTRAINT `fk_erp_vendi_change_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_vendi_change` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单变更状态表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_change_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_change_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_change_bilwfw` FOR EACH ROW BEGIN
	set new.opTime = now()
		, new.memo = concat('员工（编号：', new.empId, ' 姓名：', new.empName, '）订单变更单（编号：', new.billId,'）', new.name
							, IFNULL(new.said,' '));
END;;
DELIMITER ;