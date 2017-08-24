SET FOREIGN_KEY_CHECKS =0;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	采购退回主表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_purch_back;
CREATE TABLE `erp_purch_back` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '未提交 -1:可以修改 0:提交审核 1:通过审核，提交仓库出仓',
  `erp_purch_bil_id` bigint(20) DEFAULT NULL COMMENT '采购订单ID',
  `erp_vendi_back_id` bigint(20) DEFAULT NULL COMMENT '销售退货单ID 为空是直接采购退货',
  `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '询价单ID 冗余',
  `erp_vendi_bil_id` bigint(20) DEFAULT NULL COMMENT '销售订单ID 冗余',
  `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 跟单 erc$staff_id',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核人',
  `checkEmpId` bigint(20) DEFAULT NULL,
  `costUserId` bigint(20) DEFAULT NULL COMMENT '收款确认人',
  `costEmpId` bigint(20) DEFAULT NULL,
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '员工姓名',
  `createdBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建人员；--@CreatedBy 登录用户名',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '最新人员；--@LastModifiedBy',
  `checkEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL,
  `costEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL,
  `code` varchar(100) CHARACTER SET utf8mb4 NOT NULL COMMENT '单号 新增时触发器生成',
  `inquiryCode` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '询价单号，冗余',
  `purchCode` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '采购单号，冗余',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间；--@CreatedDate',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新时间；--@LastModifiedDate',
  `checkTime` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '审核时间',
  `costTime` datetime DEFAULT NULL COMMENT '收费时间',
  `outTime` datetime DEFAULT NULL COMMENT '出仓时间',
  `priceSumCome` decimal(20,4) DEFAULT '0.0' COMMENT '进价金额总计',
  `priceSumShip` decimal(20,4) DEFAULT '0.0' COMMENT '运费金额总计',
  `needTime` datetime DEFAULT NULL COMMENT '期限时间',
  `reason` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '采购退货原因',
  `memo` varchar(2000) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erp_purch_back_code_idx` (`code`) USING BTREE,
  KEY `erp_purch_back_inquiryCode_idx` (`inquiryCode`) USING BTREE,
  KEY `erp_purch_back_erp_vendi_back_id` (`erp_vendi_back_id`) USING BTREE,
  KEY `erp_purch_back_erp_inquiry_bil_id` (`erp_inquiry_bil_id`) USING BTREE,
  KEY `erp_purch_back_erp_vendi_bil_id` (`erp_vendi_bil_id`) USING BTREE,
  KEY `erp_purch_back_erp_purch_bil_id` (`erp_purch_bil_id`) USING BTREE,
	CONSTRAINT `fk_erp_purch_back_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) 
		REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='采购退货单主表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_back` FOR EACH ROW 
BEGIN
	DECLARE aid, aInquiryId, aVendiId, pInUserId BIGINT(20);
	DECLARE aName, aUserName, aInquiryCode, aPurchCode VARCHAR(100);
	DECLARE pCheck TINYINT;

	IF ISNULL(new.reason) OR new.reason = '' THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售退货单，必须指定退货原因！',MYSQL_ERRNO = 1001;
	END IF;

	-- 根据选取的销售订单自动写入相关信息
	IF EXISTS(SELECT 1 FROM erp_purch_bil a WHERE a.id = new.erp_purch_bil_id) THEN
		SELECT a.erp_inquiry_bil_id, a.erp_vendi_bil_id, a.inUserId, a.inquiryCode, a.purchCode, a.isCheck
		INTO aInquiryId, aVendiId, pInUserId, aInquiryCode, aPurchCode, pCheck
		FROM erp_purch_bil a WHERE a.id = new.erp_purch_bil_id;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购退货单时，必须选择有效采购订单', MYSQL_ERRNO = 1001;
	END IF;

	IF ISNULL(pInUserId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '选择采购订单没有进仓完成，不能生成退货单', MYSQL_ERRNO = 1001;
	ELSEIF pCheck <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '选择采购订单没有审核通过，不能生成退货单', MYSQL_ERRNO = 1001;
	END IF;

	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建采购退货单，必须指定最后修改用户！';
	else
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName
			, new.creatorId = new.lastModifiedId, new.empId = aid, new.empName = aName, new.createdBy = aUserName;
	end if;

	-- 写入相关字段信息
	SET new.erp_inquiry_bil_id = aInquiryId, new.erp_vendi_bil_id = aVendiId, new.inquiryCode = aInquiryCode
			, new.createdDate = NOW(), new.lastModifiedDate = NOW(), new.purchCode = aPurchCode;

	-- 生成code 8位日期+4位员工id+4位流水
	set new.code = concat(date_format(NOW(),'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_purch_back a 
				where date(a.createdDate) = date(NOW()) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);

	if isnull(new.isCheck) then
		set new.isCheck = -1;
	end if;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_AFTER_INSERT` AFTER INSERT ON `erp_purch_back` FOR EACH ROW 
BEGIN
	insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy
	, if(new.erp_purch_bil_id > 0, concat('创建采购退货单，对应采购单（编号：', new.erp_purch_bil_id, '）。')
			, concat('创建采购退货单（编号：', new.id,'）')
		);
	if ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入采购退货单状态表!';
	end if;
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_back` FOR EACH ROW 
BEGIN

	DECLARE aid bigint(20);
	DECLARE aName, aUserName varchar(100);

	-- 最后修改用户变更，获取相关信息
	IF new.lastModifiedId <> old.lastModifiedId THEN
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	END IF;

	IF ISNULL(old.costUserId) AND new.costUserId > 0 THEN -- 退款确认
		-- 根据单据状态判断是否可以确认退款
		IF new.isCheck <> 1 THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有审核通过，不能确认退款！', MYSQL_ERRNO = 1001;
		ELSEIF ISNULL(new.checkUserId) OR new.checkUserId = 0 OR new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时，最新修改员工必须与退款确认员工相同！', MYSQL_ERRNO = 1001;
		END IF;
		-- 记录收款确认人
		SET new.costEmpId = new.lastModifiedEmpId, new.costEmpName = lastModifiedEmpName, new.costTime = NOW();
		-- 记录操作状态
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'cost', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '收款确认';
	ELSEIF ISNULL(old.outTime) AND new.outTime THEN
		-- 根据单据状态判断是否可以确认退款
		IF new.isCheck <> 1 THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有审核通过，不能完成出仓！', MYSQL_ERRNO = 1001;
		END IF;
		-- 记录操作状态
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'allOut', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '所有配件出仓完毕！';
	ELSEIF old.isCheck = 0 AND new.isCheck = 1 THEN -- 审核通过（提交仓库出仓）
		if new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购退货单审核确认时，操作人和最新操作人必须是同一人！';
		end if;
		-- 记录审核人
		SET new.checkEmpId = new.lastModifiedEmpId, new.checkEmpName = new.lastModifiedEmpName, new.checkTime = NOW();
		-- 如果销售的配件还没建立配件账簿，创建
		if exists(select 1 from erp_purch_back_detail b
				where not exists(select 1 from erp_goodsbook a where a.goodsId = b.goodsId)
				limit 1
			) THEN
			insert into erp_goodsbook(goodsid)
			select distinct b.goodsId
			from erp_purch_back_detail b
			where not exists(select 1 from erp_goodsbook a where a.goodsId = b.goodsId);
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，创建配件账簿失败！';
			end if;
		end if;
		-- 修改账簿动态库存
		update erp_goodsbook a INNER JOIN erp_purch_back_detail b on a.goodsId = b.goodsId and b.erp_purch_back_id = new.id
		set a.dynamicQty = a.dynamicQty - b.qty, a.changeDate = CURDATE();
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改账簿动态库存！';
		end if;
		-- 修改日记账账簿销售动态库存
		update erp_goods_jz_day a INNER JOIN erp_purch_back_detail b on a.goodsId = b.goodsId and b.erp_purch_back_id = new.id
		set a.purchBackDynaimicQty = a.purchBackDynaimicQty - b.qty
		where a.datee = CURDATE();
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改日记账账簿动态库存！';
		end if;
		-- 按供应商生成采购退货发货单
		insert into erp_purch_back_deliv(erp_purch_back_id, supplierId, userId, lastModifiedId
			, empId, empName, userName, opTime, lastModifiedDate
			,purchCode, purchBackCode)
		select new.id, a.supplierId, new.lastModifiedId, new.lastModifiedId
			, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, now(), NOW()
			, new.purchCode, new.`code`
		FROM erp_purch_back_detail a WHERE a.erp_purch_back_id = new.id
		GROUP BY a.supplierId;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '通过审核时，无法创建采购退货发货单！';
		end if;
		-- 记录操作状态
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '审核通过';
		-- 提交出仓
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'outApply', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '提交出仓';
	ELSEIF old.isCheck = 0 AND new.isCheck = -1 THEN -- 审核不通过
		-- 根据单据状态判断是否可以审核不通过
		IF ISNULL(new.memo) OR new.memo = '' THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时，必须在备注栏指定不通过原因！！', MYSQL_ERRNO = 1001;
		ELSEIF new.creatorId = new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能由创建员工审核！！';
		END IF;
		-- 记录操作
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name, said)
		select new.id, 'checkedBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核不通过', CONCAT(' （原因：', IFNULL(new.memo, ' '), '）');
	ELSEIF old.isCheck = -1 AND new.isCheck = 0 THEN -- 提交待审
		-- 判断采购退货明细是否存在没有制定供应商的
		IF EXISTS(SELECT 1 FROM erp_purch_back_detail a WHERE a.erp_purch_back_id = new.id AND ISNULL(a.supplierId) LIMIT 1) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购退货单提交待审前，请补全明细中配件的供应商！！';
		END IF;
		-- 记录操作状态
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'submitBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '提交待审';
	ELSE
		IF new.erp_purch_bil_id <> old.erp_purch_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定采购订单，不能修改！！';
		ELSEIF old.costUserId > 0 OR new.costUserId > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购退货单已退款给用户，不能修改！！';
		ELSEIF old.isCheck > -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购退货单已提交待审或审核通过，不能修改！！';
		ELSEIF new.priceSumCome <> old.priceSumCome THEN
			-- 获取对应采购单总进货价
			IF EXISTS(SELECT 1 FROM erp_purch_bil a WHERE a.id = new.erp_purch_bil_id AND a.priceSumCome < new.priceSumCome) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改采购退货单时，退款总价不能大于采购订单总价！！';
			END IF;
		END IF;
		-- 记录操作状态
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '自行修改';
	END IF;

	set new.lastModifiedDate = CURRENT_TIMESTAMP();

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_BEFORE_DELETE` BEFORE DELETE ON `erp_purch_back` FOR EACH ROW BEGIN
	if old.outTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已出仓完毕，不能删除！';
	elseif old.costTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已收款，不能删除！';
	elseif old.isCheck > -1 then
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交审核或审核通过，不能删除！';
	END IF;
	-- 删除采购退货明细
	delete a from erp_purch_back_detail a where a.erp_erp_purch_back_id = old.id;
	-- 删除采购退货单流程表
	DELETE a FROM erp_purch_back_bilwfw a WHERE a.billId = old.id;
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	采购退回明细表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_purch_back_detail;
CREATE TABLE `erp_purch_back_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_back_id` bigint(20) NOT NULL COMMENT '采购订单主表ID',
  `erp_purch_detail_id` bigint(20) NOT NULL COMMENT '采购明细主表ID',
  `erp_vendi_back_detail_id` bigint(20) DEFAULT NULL COMMENT '销售明细表ID',
  `goodsId` bigint(20) NOT NULL COMMENT '配件',
  `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商',
  `ers_packageAttr_id` bigint(20) NOT NULL COMMENT '商品的包装ID',
  `packageQty` int(11) NOT NULL COMMENT '包装数量',
  `packageUnit` varchar(30) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '包裹单位 是否需要',
  `qty` int(11) DEFAULT NULL COMMENT '单品数量',
  `packagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装单价',
  `price` decimal(20,4) DEFAULT '0.0000' COMMENT '进价',
  `amt` decimal(20,4) DEFAULT '0.0000' COMMENT '进价金额',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间；--@CreatedDate',
  `outTime` datetime DEFAULT NULL COMMENT '出仓时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新时间；--@LastModifiedDate',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '最新修改人登录帐号ID，前端传入',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '最新修改人员登录名称；--@LastModifiedBy',
  `reason` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '配件退货原因',
  `memo` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_purch_back_detail_erp_purch_back_id` (`erp_purch_back_id`,`goodsId`) USING BTREE,
  KEY `erp_purch_back_detail_goodsId_idx` (`goodsId`) USING BTREE,
  KEY `erp_purch_back_detail_erp_purch_detail_id_idx` (`erp_purch_detail_id`) USING BTREE,
  KEY `erp_purch_back_detail_erp_vendi_back_detail_id_idx` (`erp_vendi_back_detail_id`) USING BTREE,
  KEY `erp_purch_back_detail_ers_packageAttr_id_idx` (`ers_packageAttr_id`,`erp_purch_back_id`) USING BTREE,
  CONSTRAINT `fk_erp_purch_back_detail_erp_purch_back_id` FOREIGN KEY (`erp_purch_back_id`) 
		REFERENCES `erp_purch_back` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_purch_back_detail_ers_packageAttr_id` FOREIGN KEY (`ers_packageAttr_id`) 
		REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_erp_purch_back_detail_erp_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='采购退货明细'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_back_detail` FOR EACH ROW BEGIN
	DECLARE msg varchar(1000);
	DECLARE aid, aPurchId, bGoodsId, bSupplierId, bPurchId, cGoodsId BIGINT(20);
	DECLARE aName, aUserName, bPackageUnit VARCHAR(100);
	DECLARE aCheck TINYINT;
	DECLARE oTime, cTime datetime;
	DECLARE aQty, bQty, cQty, sQty INT;
	DECLARE bPrice DECIMAL(20,4);

	SET msg = concat('采购退货单（编号：', new.erp_purch_back_id, ', ）');
	SELECT a.isCheck, a.outTime, a.costTime, a.erp_purch_bil_id
	INTO aCheck, oTime, cTime, aPurchId
	FROM erp_purch_back a WHERE a.id = new.erp_purch_back_id;

	IF cTime > 0 THEN
		set msg = concat(msg, '已审核通过并收款确认，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF oTime > 0 THEN
		set msg = concat(msg, '已出仓，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(new.reason) OR new.reason = '' THEN
		set msg = concat(msg, '必须指定配件退货原因！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取采购明细相关信息
	SELECT a.goodsId, a.supplierId, a.packageUnit, a.qty, a.price, a.erp_purch_bil_id
	INTO bGoodsId, bSupplierId, bPackageUnit, bQty, bPrice, bPurchId
	FROM erp_purch_detail a WHERE a.id = new.erp_purch_detail_id;
	-- 获取包装属性表信息
	SELECT a.actualQty, a.goodsId
	INTO cQty, cGoodsId
	FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;

	IF ISNULL(aPurchId) OR ISNULL(bPurchId) OR aPurchId <> bPurchId THEN
		set msg = concat(msg, '选择的采购明细与采购退货单选择的采购订单不对应，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF bGoodsId <> cGoodsId THEN
		SET msg = concat(msg, '必须指定有效的包装！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.ers_packageAttr_id) OR new.ers_packageAttr_id = 0 THEN
		SET msg = concat(msg, '必须指定有效的包装！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF new.packageQty < 1 OR isnull(new.packageQty) THEN
		SET msg = concat(msg, '必须指定有效的数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.lastModifiedId) OR new.lastModifiedId = 0 THEN
		SET msg = concat(msg, '必须指定有效的创建人！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取动、静态库存量
	SELECT a.dynamicQty, a.staticQty INTO aQty, sQty FROM erp_goodsbook a WHERE a.goodsId = bGoodsId;

	-- 最后修改用户变更
	call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
	set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;

	-- 设置相关信息
	SET new.goodsId = bGoodsId, new.supplierId = bSupplierId, new.packageUnit = bPackageUnit, new.qty = new.packageQty * cQty
		, new.packagePrice = bPrice * cQty, new.price = bPrice, new.amt = new.packagePrice * new.packageQty
		, new.createdDate = NOW(), new.lastModifiedDate = NOW();

	-- 判断数量是否大于采购明细数量
	IF new.qty > bQty THEN
		SET msg = concat(msg, '配件退货数量不能大于采购数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF new.qty > aQty THEN
		SET msg = concat(msg, '配件退货数量不能大于动态库存数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF new.qty > sQty THEN
		SET msg = concat(msg, '配件退货数量不能大于静态库存数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 更新主表总价钱
	UPDATE erp_purch_back a
	SET a.priceSumCome = a.priceSumCome + new.amt
	WHERE a.id = new.erp_purch_back_id;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_detail_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_detail_AFTER_INSERT` AFTER INSERT ON `erp_purch_back_detail` FOR EACH ROW BEGIN
	-- 插入流程表
	insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.erp_purch_back_id, 'append', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
		, new.lastModifiedBy, '追加配件';
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_back_detail` FOR EACH ROW BEGIN

	DECLARE msg VARCHAR(1000);
	DECLARE aCheck TINYINT;
	DECLARE oTime, cTime datetime;
	DECLARE aid, bGoodsId BIGINT(20);
	DECLARE aName, aUserName, bPackageUnit VARCHAR(100);
	DECLARE aQty, bQty, sQty, dQty INT;
	
	SET msg = concat('修改采购退货单（编号：', new.erp_purch_back_id, ', ）明细（编号：', new.id, '）时，');

	-- 获取主表信息
	SELECT a.isCheck, a.outTime, a.costTime
	INTO aCheck, oTime, cTime
	FROM erp_purch_back a WHERE a.id = new.erp_purch_back_id;

	-- 已进仓完毕之后不能修改
	IF old.outTime > 0 THEN
		set msg = concat(msg, '仓库已完成出仓，不能修改！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	IF new.outTime > 0 AND ISNULL(old.outTime) THEN
		IF aCheck <> 1 THEN
			set msg = concat(msg, '采购退货单没有审核通过，不能出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.packageQty <> old.packageQty THEN
			set msg = concat(msg, '进仓完毕时，不能修改数量！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.amt <> old.amt THEN
			set msg = concat(msg, '进仓完毕时，不能修改进货价钱！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录操作流程
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_purch_back_id, 'out', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('采购退货明细（编号：', new.id, '）出仓完毕！');
	ELSE
		-- 修改关键信息
		IF new.erp_purch_detail_id <> old.erp_purch_detail_id THEN
			set msg = concat(msg, '已指定退货配件，不能修改配件，请删除再添加！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.ers_packageAttr_id <> old.ers_packageAttr_id THEN -- 更换包装
			-- 获取对应采购明细信息
			SELECT a.qty INTO aQty FROM erp_purch_detail a WHERE a.id = new.erp_purch_detail_id;
			-- 获取动、静态库存量
			SELECT a.dynamicQty, a.staticQty INTO dQty, sQty FROM erp_goodsbook a WHERE a.goodsId = new.goodsId;
			-- 获取单包装实际单品数量
			SELECT a.actualQty, a.packageUnit, a.goodsId 
			INTO bQty, bPackageUnit, bGoodsId 
			FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
			-- 更新单品数量、进货包装单价、进货总价
			SET new.qty = bQty * new.packageQty, new.packagePrice = new.price * bQty, new.amt = new.packagePrice * new.packageQty;
			-- 判断单品数量是否超过采购明细单品数量
			IF new.goodsId <> bGoodsId THEN
				SET msg = concat(msg, '请指定有效包装单位！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.qty > aQty THEN
				SET msg = concat(msg, '配件退货数量不能大于采购数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.qty > dQty THEN
				SET msg = concat(msg, '配件退货数量不能大于动态库存数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.qty > sQty THEN
				SET msg = concat(msg, '配件退货数量不能大于静态库存数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		ELSEIF new.packageQty <> old.packageQty THEN
			-- 获取对应采购明细信息
			SELECT a.qty INTO aQty FROM erp_purch_detail a WHERE a.id = new.erp_purch_detail_id;
			-- 获取单包装实际单品数量
			SELECT a.actualQty INTO bQty FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
			-- 获取动、静态库存量
			SELECT a.dynamicQty, a.staticQty INTO dQty, sQty FROM erp_goodsbook a WHERE a.goodsId = new.goodsId;
			-- 更新单品数量、进货价
			SET new.qty = bQty * new.packageQty, new.amt = new.packagePrice * new.packageQty;
			-- 判断单品数量是否超过采购明细单品数量
			IF new.qty > aQty THEN
				SET msg = concat(msg, '配件退货数量不能大于采购数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.qty > dQty THEN
				SET msg = concat(msg, '配件退货数量不能大于动态库存数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.qty > sQty THEN
				SET msg = concat(msg, '配件退货数量不能大于静态库存数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		END IF;

		IF cTime > 0 THEN
			set msg = concat(msg, '已收款确认，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF oTime > 0 THEN
			set msg = concat(msg, '已出仓，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aCheck > -1 THEN
			set msg = concat(msg, '已进入提交待审或审核通过，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif new.packageQty < 1 OR isnull(new.packageQty) THEN
			set msg = concat(msg, '追必须指定有效的数量！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif isnull(new.lastModifiedId) or new.lastModifiedId = 0 then
			set msg = concat(msg, '必须指定有效的修改员工！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
	END IF;

	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;

	-- 更新主表总价钱
	IF new.amt <> old.amt THEN
		UPDATE erp_purch_back a SET a.priceSumCome = a.priceSumCome + new.amt - old.amt
		WHERE a.id = new.erp_purch_back_id;
	ELSEIF ISNULL(new.amt) OR new.amt < 1 THEN
		set msg = concat(msg, '价格不能为空！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end IF;

	-- 记录操作流程
	insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.erp_purch_back_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
		, new.lastModifiedBy, '自行修改采购退货单明细';

	SET new.lastModifiedDate = NOW();
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_purch_back_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_purch_back_detail` FOR EACH ROW BEGIN
	declare msg VARCHAR(1000);
	DECLARE aCheck TINYINT;
	DECLARE cTime, oTime datetime;

	SET msg = concat('删除采购退货单（编号：', old.erp_purch_back_id, ', ）明细（编号：', old.id,'）');
	SELECT a.isCheck, a.costTime, a.outTime
	INTO aCheck, cTime, oTime
	FROM erp_purch_back a WHERE a.id = old.erp_purch_back_id;
	-- 根据主表状态判断是否能删除
	IF cTime > 0 THEN
		set msg = concat(msg, '已收款，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF oTime > 0 THEN
		set msg = concat(msg, '已出仓，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 更新主表总价钱
	UPDATE erp_purch_back a 
	SET a.priceSumCome = a.priceSumCome - old.amt
	WHERE a.id = old.erp_purch_back_id;
	-- 记录删除操作
	insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select old.erp_purch_back_id, 'delete', old.lastModifiedId, old.lastModifiedEmpId, old.lastModifiedEmpName, old.lastModifiedBy
		, CONCAT('删除销售退货明细（编号：', old.id, '，销售退货单编号：', old.erp_purch_back_id
				, '，销售明细编号：', old.erp_purch_detail_id,'，配件编号：', old.goodsId, '）');
end;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	采购退回状态表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_purch_back_bilwfw;
CREATE TABLE `erp_purch_back_bilwfw` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billId` bigint(20) DEFAULT NULL COMMENT '单码',
  `billStatus` varchar(50) CHARACTER SET utf8mb4 NOT NULL COMMENT '单状态',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '员工姓名',
  `userName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '登陆用户名',
  `name` varchar(255) CHARACTER SET utf8mb4 NOT NULL COMMENT '步骤名称',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `said` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '步骤附言',
  `memo` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '其他关联',
  PRIMARY KEY (`id`),
  KEY `userId_idx` (`userId`),
  KEY `billStatus_idx` (`billStatus`),
  KEY `opTime_idx` (`opTime`),
  KEY `erp_purch_back_bilwfw_billId_idx` (`billId`),
  CONSTRAINT `fk_erp_purch_back_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_purch_back` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='采购退货状态表'
;

DROP TRIGGER IF EXISTS tr_erp_purch_back_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_back_bilwfw` FOR EACH ROW BEGIN
	set new.opTime = now()
		,new.memo = concat('员工（编号：', IFNULL(new.empId,' '), ' 姓名：', IFNULL(new.empName,' ')
		, '）采购退货单（编号：', IFNULL(new.billId,' '),'）', IFNULL(new.name,' '), IFNULL(new.said,' '));
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	采购退货发货单
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_purch_back_deliv;
CREATE TABLE `erp_purch_back_deliv` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_back_id` bigint(20) NOT NULL COMMENT '采购退货单ID',
  `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商id autopart01_crm.erc$supplier.id',
  `supplierName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '供应商名称，冗余',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `shipperId` bigint(20) DEFAULT NULL COMMENT '物流商id autopart01_crm.erc$shipper.id',
  `packageQty` int(11) DEFAULT NULL COMMENT '发货时打包件数',
  `shipperName` varchar(130) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '物流商名称 冗余',
  `userName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '登陆用户名',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '员工姓名',
  `delivTime` datetime DEFAULT NULL COMMENT '发货时间。',
  `endTime` datetime DEFAULT NULL COMMENT '签收时间。非空表示供应商签收',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `delivUserId` bigint(20) DEFAULT NULL COMMENT '发货人登录ID',
  `delivEmpId` bigint(20) DEFAULT NULL COMMENT '发货员工ID',
  `delivEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '发货员工姓名',
  `lastModifiedId` bigint(20) DEFAULT NULL,
  `lastModifiedDate` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '最新时间',
  `purchCode` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '采购单号',
  `purchBackCode` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '采购退货单号，冗余',
  `pickNo` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '货运单号',
  `memo` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '货物中途信息',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL,
  `takeGeoTel` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `purch_back_deliv_erp_purch_back_id_idx` (`erp_purch_back_id`,`supplierId`),
  KEY `purch_back_deliv_supplierId_idx` (`supplierId`),
  KEY `purch_back_deliv_opTime_idx` (`opTime`),
  KEY `purch_back_deliv_shipperId_idx` (`shipperId`) USING BTREE,
  KEY `purch_back_deliv_purchBackCode_idx` (`purchBackCode`) USING BTREE,
  KEY `purch_back_deliv_purchCode_idx` (`purchCode`) USING BTREE,
  CONSTRAINT `fk_purch_back_deliv_erp_purch_back_id` FOREIGN KEY (`erp_purch_back_id`) 
		REFERENCES `erp_purch_back` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='采购退货发货单';

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_back_deliv_before_insert`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_deliv_before_insert` BEFORE INSERT ON `erp_purch_back_deliv` FOR EACH ROW BEGIN
	
	IF EXISTS(SELECT 1 FROM autopart01_crm.`erc$supplier` a WHERE a.id = new.supplierId) THEN
		SET new.supplierName = (SELECT a.`name` FROM autopart01_crm.`erc$supplier` a WHERE a.id = new.supplierId);
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效供应商！！';
	END IF;

end;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_back_deliv_before_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_back_deliv_before_update` BEFORE UPDATE ON `erp_purch_back_deliv` FOR EACH ROW BEGIN
	DECLARE aId BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);

	if new.shipperId > 0 and (isnull(old.shipperId) or new.shipperId <> old.shipperId) then 
		set new.shipperName = (select a.name from autopart01_crm.erc$shipper a where a.id = new.shipperId);
	end if;
	-- 采购退货发货出发
	if new.delivUserId > 0 and isnull(old.delivUserId) THEN
		IF new.delivUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购退货发货出发确认时，操作人和最新操作人必须是同一人！';
		END IF;
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.delivTime = NOW(), new.delivEmpId = aId, new.delivEmpName = aName;
		-- 记录操作
		insert into erp_purch_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_purch_back_id, 'delivBegin', new.lastModifiedId, aId, aName, aUserName
			, CONCAT('采购退货发货出发，供应商（编号：', new.supplierId, '，名称：', new.supplierName, '）');
	end if;
end;;
DELIMITER ;