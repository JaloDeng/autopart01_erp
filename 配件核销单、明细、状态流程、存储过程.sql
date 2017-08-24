SET FOREIGN_KEY_CHECKS =0;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	配件核销单主表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_goods_cancel;
CREATE TABLE `erp_goods_cancel` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '是否提交审核。-1：可以更改；0：提交待审，不能更改 1：审核通过，不能更改，可以出仓',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新操作用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新操作员工ID',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `outUserId` bigint(20) DEFAULT NULL COMMENT '出仓用户ID，非空为已出仓',
  `outEmpId` bigint(20) DEFAULT NULL COMMENT '出仓员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '初建员工姓名',
  `createdBy` varchar(255) DEFAULT NULL COMMENT '初建登录账户名称',
  `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新操作员工姓名',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新操作登录账户名称',
  `checkEmpName` varchar(100) DEFAULT NULL COMMENT '审核员工姓名，跟单审核',
  `outEmpName` varchar(100) DEFAULT NULL COMMENT '核销出仓员工姓名',
  `code` varchar(100) NOT NULL COMMENT '核销单单号 新增时触发器生成 GC:goods_cancel',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `outTime` datetime DEFAULT NULL COMMENT '出仓时间',
  `priceSumCome` decimal(20,4) DEFAULT '0.0000' COMMENT '进价金额总计',
  `reason` varchar(255) DEFAULT NULL COMMENT '核销原因',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erp_goods_cancel_code_idx` (`code`) USING BTREE,
  KEY `erp_goods_cancel_isCheck_idx` (`isCheck`) USING BTREE,
  KEY `erp_goods_cancel_outTime_idx` (`outTime`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='配件核销单主表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_BEFORE_INSERT` BEFORE INSERT ON `erp_goods_cancel` FOR EACH ROW BEGIN
	
	DECLARE aid BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);

	-- 新增配件核销单时必须指定原因
	IF ISNULL(new.reason) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增配件核销单，必须指定核销原因！';
	END IF;
	-- 最后修改用户变更，获取相关信息
	IF isnull(new.lastModifiedId) OR new.lastModifiedId < 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建配件核销单，必须指定有效用户！';
	ELSEIF isnull(new.lastModifiedEmpId) THEN
		CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		SET new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName,
				new.creatorId = new.lastModifiedId, new.empId = aid, new.empName = aName, new.createdBy = aUserName;
	END IF;
	-- 生成code 'GC'+8位日期+4位员工id+4位流水
	SET new.code = concat('GC', date_format(NOW(),'%Y%m%d'), LPAD(new.lastModifiedId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_goods_cancel a 
				where date(a.createdDate) = date(NOW()) and a.creatorId = new.lastModifiedId), 0
			) + 1, 4, 0)
	);

	IF ISNULL(new.isCheck) THEN
		SET new.isCheck = -1;
	END IF;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_AFTER_INSERT` AFTER INSERT ON `erp_goods_cancel` FOR EACH ROW BEGIN
	-- 写入核销单流程状态表
	INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	SELECT new.id, 'justcreated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
			, '刚刚创建核销单主表';
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_BEFORE_UPDATE` BEFORE UPDATE ON `erp_goods_cancel` FOR EACH ROW BEGIN

	DECLARE aid bigint(20);
	DECLARE aName, aUserName varchar(100);
	DECLARE msg VARCHAR(1000);

	-- 所有配件核销出仓完毕后不能修改
	IF old.outUserId > 0 THEN
		SET msg = CONCAT('核销单（编号：', new.id, '）已经出仓完成，不能修改！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		IF new.lastModifiedId < 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改配件核销单，必须指定有效用户！', MYSQL_ERRNO = 1001;
		END IF;
		CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;

	IF ISNULL(old.outUserId) AND new.outUserId > 0 THEN -- 所有配件出仓完成
		IF new.isCheck <> 1 THEN
			SET msg = CONCAT('核销单（编号：', new.id, '）没有审核通过，不能核销出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.outUserId <> new.lastModifiedId THEN
			SET msg = CONCAT('核销单（编号：', new.id, '）出仓完成时，出仓人和最新操作人必须相同！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录出仓人信息
		SET new.outEmpId = new.lastModifiedEmpId, new.outEmpName = new.lastModifiedEmpName, new.outTime = NOW();
		-- 记录操作
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
			SELECT new.id, 'allOut', new.lastModifiedId,  new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, CONCAT('核销单（编号：', new.id, '）', '所有核销配件出仓完成！');
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '出仓完成，未能记录操作流程！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
	ELSEIF old.isCheck = 0 AND new.isCheck = 1 THEN -- 审核通过，可以出仓
		IF new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '通过审核时，最新修改员工必须与审核员工相同！', MYSQL_ERRNO = 1001;
		ELSEIF new.creatorId = new.checkUserId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '创建员工不能审核！', MYSQL_ERRNO = 1001;
		END IF;
		-- 记录审核人，审核时间
		set new.checkEmpId = new.lastModifiedEmpId, new.checkEmpName = new.lastModifiedEmpName, new.checkTime = NOW();
		-- 修改账簿动态库存
		UPDATE erp_goodsbook a 
			INNER JOIN (SELECT d.goodsId, SUM(d.qty) AS qty FROM erp_goods_cancel_detail d 
				WHERE d.erp_goods_cancel_id = new.id GROUP BY d.goodsId
			) b ON b.goodsId = a.goodsId
		SET a.dynamicQty = a.dynamicQty - b.qty, a.changeDate = CURDATE()
		;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改账簿动态库存！';
		end if;
		-- 修改日记账账簿核销动态库存
		UPDATE erp_goods_jz_day a 
			INNER JOIN (SELECT d.goodsId, SUM(d.qty) AS qty FROM erp_goods_cancel_detail d 
				WHERE d.erp_goods_cancel_id = new.id GROUP BY d.goodsId
			) b ON b.goodsId = a.goodsId
		SET a.cancelDynaimicQty = a.cancelDynaimicQty - b.qty
		WHERE a.datee = CURDATE()
		;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改日记账账簿核销动态库存！';
		end if;
		-- 记录操作
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核通过';
	ELSEIF old.isCheck = 0 AND new.isCheck = -1 THEN -- 审核不通过
		IF ISNULL(new.memo) OR new.memo = '' THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时，必须在备注栏指定不通过原因！！', MYSQL_ERRNO = 1001;
		ELSEIF new.creatorId = new.checkUserId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '创建员工不能审核！', MYSQL_ERRNO = 1001;
		END IF;
		-- 记录操作
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name, said)
		SELECT new.id, 'checkedBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核不通过', CONCAT(' （原因：', IFNULL(new.memo, ' '), '）');
	ELSEIF old.isCheck = -1 AND new.isCheck = 0 THEN -- 提交待审
		-- 记录操作
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.id, 'submitCheck', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '提交待审';
	ELSE
		IF new.isCheck > -1 THEN
			SET msg = CONCAT('核销单（编号：', new.id, '）已经提交待审或者审核通过，不能修改！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录修改操作
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
			, '修改配件核销单主表';
	END IF;
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_BEFORE_DELETE` BEFORE DELETE ON `erp_goods_cancel` FOR EACH ROW BEGIN
	IF old.outUserId > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '配件核销单已出仓完成，不能删除！';
	ELSEIF old.isCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '配件核销单已提交待审或审核通过，不能删除！';
	END IF;
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	配件核销单明细表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_goods_cancel_detail`;
CREATE TABLE `erp_goods_cancel_detail` (
	`id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_goods_cancel_id` bigint(20) NOT NULL COMMENT '核销单主表ID',
  `erp_purchDetail_snCode_id` bigint(20) NOT NULL COMMENT '配件二维码ID',
  `goodsId` bigint(20) DEFAULT NULL COMMENT '货品编码',
	`goodsName` VARCHAR(100) DEFAULT NULL COMMENT '配件名称',
  `roomId` bigint(20) DEFAULT NULL COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库',
  `ers_shelfattr_id` bigint(20) DEFAULT NULL COMMENT '货架编码',
  `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
  `packageQty` int(11) DEFAULT '1' COMMENT '数量；--包装数量',
  `qty` decimal(20,4) DEFAULT NULL COMMENT '数量；--最小粒度单位的数量',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新操作用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新操作员工ID',
	`lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新操作员工姓名',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新操作登录账户名称',
  `outTime` datetime DEFAULT NULL COMMENT '出仓时间',
  `outUserId` bigint(20) DEFAULT NULL COMMENT '出仓人，非空为已出仓核销',
  `outEmpId` bigint(20) DEFAULT NULL COMMENT '出仓员工ID',
  `outEmpName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `packagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装进货单价',
	`reason` varchar(255) DEFAULT NULL COMMENT '核销原因',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
	UNIQUE KEY `goods_cancel_detail_snCode_id` (`erp_purchDetail_snCode_id`) USING BTREE,
  KEY `goods_cancel_detail_goods_cancel_id` (`erp_goods_cancel_id`) USING BTREE,
  KEY `goods_cancel_detail_goodsId` (`goodsId`,`erp_goods_cancel_id`) USING BTREE,
  CONSTRAINT `fk_goods_cancel_detail_goods_cancel_id` FOREIGN KEY (`erp_goods_cancel_id`) 
		REFERENCES `erp_goods_cancel` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_goods_cancel_detail_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_goods_cancel_detail_shelfId` FOREIGN KEY (`ers_shelfattr_id`) 
		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='核销单明细'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_goods_cancel_detail` FOR EACH ROW BEGIN

	DECLARE aCheck, aState, aStockState TINYINT;
	DECLARE aOutUserId, aid, aGoodsId, sRoomId, aShelfId, aPackageId, aShelfBookId BIGINT(20);
	DECLARE aQty INT;
	DECLARE msg VARCHAR(1000);
	DECLARE aName, aUserName, aGoodsName VARCHAR(100);
	DECLARE aPrice DECIMAL(20,4);

	-- 新增配件核销明细时必须指定原因
	IF ISNULL(new.reason) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增配件核销明细，必须指定配件核销原因！';
	END IF;

	SELECT a.isCheck, a.outUserId 
	INTO aCheck, aOutUserId
	FROM erp_goods_cancel a WHERE a.id = new.erp_goods_cancel_id;

	SET msg = '追加配件核销明细时，';

	IF aOutUserId > -1 THEN
		SET msg = CONCAT(msg, '配件核销单（编号：', new.erp_goods_cancel_id, '）已出仓完毕，不能追加明细！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		SET msg = CONCAT(msg, '配件核销单（编号：', new.erp_goods_cancel_id, '）已提交待审或审核通过，不能追加明细！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 最后修改用户
	IF ISNULL(new.lastModifiedId) OR new.lastModifiedId < 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增核销配件明细时，必须指定有效用户！';
	ELSE
		CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		SET new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	END IF;

	IF ISNULL(new.erp_purchDetail_snCode_id) OR new.erp_purchDetail_snCode_id < 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增核销单必须指定有效货物二维码编号！';
	ELSE
		-- 获取新二维码相关信息
		SELECT a.goodsId, s.id, a.ers_shelfattr_id, a.ers_shelfbook_id, a.ers_packageattr_id
			, a.qty, a.state, a.stockState, pd.price, g.`name`
		INTO aGoodsId, sRoomId, aShelfId, aShelfBookId, aPackageId
			, aQty, aState, aStockState, aPrice, aGoodsName
		FROM erp_purchdetail_sncode a 
		INNER JOIN ers_roomattr s ON s.id = a.roomId
		INNER JOIN erp_purch_detail pd ON pd.id = a.erp_purch_detail_id
		INNER JOIN erp_goods g ON g.id = a.goodsId
		WHERE a.id = new.erp_purchDetail_snCode_id;

		IF ISNULL(aGoodsId) OR aGoodsId < 0 THEN
			SET msg = '该货物二维码不存在或还没进仓或者对应仓库不存在，不能核销！';
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aState <> 1 THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '）已出仓或者还没进仓，不能核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aStockState <> 0 THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '）已备货，不能核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aShelfBookId = -1 THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '）已被拆包，不能整体核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;

		-- 是否存在低级二维码出仓或备货，存在则不能整体核销
		if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
			where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.state = -1
				and b.id = new.erp_purchDetail_snCode_id and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：'
				, new.erp_purchDetail_snCode_id, '）包装存在低级包装出仓的记录，不能进行整体核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF EXISTS (select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
			where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.stockState = 1
				and b.id = new.erp_purchDetail_snCode_id and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：'
				, new.erp_purchDetail_snCode_id, '）包装存在低级包装备货的记录，不能进行整体核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

		-- 更新相关新二维码信息
		SET new.goodsId = aGoodsId, new.roomId = sRoomId, new.ers_shelfattr_id = aShelfId
			, new.ers_packageattr_id = aPackageId, new.qty = aQty, new.packagePrice = aPrice * aQty
			, new.goodsName = aGoodsName;

		-- 更新主表核销总价
		UPDATE erp_goods_cancel a SET a.priceSumCome = a.priceSumCome + new.packagePrice, a.lastModifiedId = new.lastModifiedId
		WHERE a.id = new.erp_goods_cancel_id;

	END IF;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_detail_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_detail_AFTER_INSERT` AFTER INSERT ON `erp_goods_cancel_detail` FOR EACH ROW BEGIN
	-- 写入核销单流程状态表
	INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	SELECT new.erp_goods_cancel_id, 'justcreated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
			, CONCAT('刚刚创建核销单明细（编号：', new.id, '），配件（编号：', new.goodsId, '，二维码编号：', new.erp_purchDetail_snCode_id
			, '），仓位（编号：', new.ers_shelfattr_id, '）。');
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_goods_cancel_detail` FOR EACH ROW BEGIN

	DECLARE aCheck, aState, aStockState TINYINT;
	DECLARE aid, aGoodsId, sRoomId, aShelfId, aPackageId, aShelfBookId BIGINT(20);
	DECLARE aQty INT;
	DECLARE msg VARCHAR(1000);
	DECLARE aName, aUserName, aGoodsName VARCHAR(100);
	DECLARE aPrice DECIMAL(20,4);

	SET msg = '修改配件核销单明细时，';

	-- 所有配件核销出仓完毕后不能修改
	IF old.outUserId > 0 THEN
		SET msg = CONCAT('核销明细（编号：', new.id, '，配件编号：', new.goodsId
			, ', 二维码编号：', new.erp_purchDetail_snCode_id, '）已经出仓完成，不能修改！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 最后修改用户变更，获取相关信息
	IF new.lastModifiedId <> old.lastModifiedId THEN
		IF new.lastModifiedId < 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改配件核销明细时，必须指定有效用户！', MYSQL_ERRNO = 1001;
		END IF;
		CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		SET new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	END IF;

	-- 获取主表审核状态
	SELECT a.isCheck INTO aCheck FROM erp_goods_cancel a WHERE a.id = new.erp_goods_cancel_id;

	IF new.outUserId > 0 AND ISNULL(old.outUserId) THEN -- 核销出仓
		-- 审核通过才能出仓
		IF aCheck <> 1 THEN
			SET msg = CONCAT(msg, '配件（编号：', new.goodsId, '，二维码编号：', new.erp_purchDetail_snCode_id
					, '）对应的配件核销单（编号：', new.erp_goods_cancel_id, '）没有审核通过，不能出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.outUserId <> new.lastModifiedId THEN
			SET msg = CONCAT('核销明细（编号：', new.id, '），配件（编号：', new.goodsId, '，二维码编号：'
				, new.erp_purchDetail_snCode_id, '出仓时，出仓人和最新操作人必须相同！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 修改仓位库存
		update ers_shelfBook a 
		set a.packageQty = a.packageQty - new.packageQty, a.qty = a.qty - new.qty
		where a.ers_packageattr_id = new.ers_packageattr_id and a.ers_shelfattr_id = new.ers_shelfattr_id;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能同步修改仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 修改日记账账簿静态库存
		update erp_goods_jz_day a 
		set a.cancelStaticQty = a.cancelStaticQty - new.qty
		where a.goodsId = new.goodsId and a.datee = CURDATE();
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '配件核销出仓时，未能成功修改日记账账簿静态库存！';
		end if;
		-- 登记出仓人
		SET new.outEmpId = new.lastModifiedEmpId, new.outEmpName = new.lastModifiedEmpName, new.outTime = NOW();
		-- 记录流程
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
				SELECT new.erp_goods_cancel_id, 'out', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, CONCAT('核销单明细（编号：', new.id, '），配件（编号：', new.goodsId, '，二维码编号：'
				, new.erp_purchDetail_snCode_id, '），仓位（编号：', new.ers_shelfattr_id, '）核销出仓完成。');

	ELSEIF new.erp_purchDetail_snCode_id <> old.erp_purchDetail_snCode_id THEN -- 更改货物二维码
		IF new.erp_purchDetail_snCode_id < 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改配件核销单明细时，必须指定有效货物二维码！';
		ELSEIF aCheck > -1 THEN
			SET msg = CONCAT(msg, '配件核销单（编号：', new.erp_goods_cancel_id, '）已提交待审或审核通过，不能修改货物二维码！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 获取新二维码相关信息
		SELECT a.goodsId, s.id, a.ers_shelfattr_id, a.ers_shelfbook_id, a.ers_packageattr_id
			, a.qty, a.state, a.stockState, pd.price, g.`name`
		INTO aGoodsId, sRoomId, aShelfId, aShelfBookId, aPackageId
			, aQty, aState, aStockState, aPrice, aGoodsName
		FROM erp_purchdetail_sncode a 
		INNER JOIN ers_roomattr s ON s.id = a.roomId
		INNER JOIN erp_purch_detail pd ON pd.id = a.erp_purch_detail_id
		INNER JOIN erp_goods g ON g.id = new.goodsId
		WHERE a.id = new.erp_purchDetail_snCode_id;
		-- 判断二维码相关信息
		IF ISNULL(aGoodsId) OR aGoodsId < 0 THEN
			SET msg = '该货物二维码不存在或还没进仓或者对应仓库不存在，不能核销！';
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aState <> 1 THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '）已出仓或者还没进仓，不能核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aStockState <> 0 THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '）已备货，不能核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF aShelfBookId = -1 THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '）已被拆包，不能整体核销！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 是否存在低级二维码出仓或备货，存在则不能整体核销
		if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
			where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.state = -1
				and b.id = new.erp_purchDetail_snCode_id and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：'
				, new.erp_purchDetail_snCode_id, '）包装存在低级包装出仓的记录，不能进行整体出仓');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF EXISTS (select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
			where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.stockState = 1
				and b.id = new.erp_purchDetail_snCode_id and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SET msg = CONCAT(msg, '配件（编号：', aGoodsId, '，二维码编号：'
				, new.erp_purchDetail_snCode_id, '）包装存在低级包装备货的记录，不能进行整体出仓');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
		-- 更新相关新二维码信息
		SET new.goodsId = aGoodsId, new.roomId = sRoomId, new.ers_shelfattr_id = aShelfId
			, new.ers_packageattr_id = aPackageId, new.qty = aQty, new.packagePrice = aPrice * aQty
			, new.goodsName = aGoodsName;
		-- 更新主表核销总价
		UPDATE erp_goods_cancel a SET a.priceSumCome = a.priceSumCome + new.packagePrice - old.packagePrice
		WHERE a.id = new.erp_goods_cancel_id;
		-- 记录流程
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
			SELECT new.erp_goods_cancel_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('修改核销单明细（编号：', new.id, '），旧配件（编号：', old.goodsId, '，二维码编号：'
			, old.erp_purchDetail_snCode_id, '，仓位编号：', old.ers_shelfattr_id, '），新配件（编号：'
			, new.goodsId, '，二维码编号：', new.erp_purchDetail_snCode_id, '，仓位编号：', new.ers_shelfattr_id, '）。');
	ELSE
		-- 根据状态是否可以更改
-- 		IF aCheck > -1 THEN
-- 			SET msg = CONCAT(msg, '配件核销单（编号：', new.erp_goods_cancel_id, '）已提交待审或审核通过，不能修改配件核销明细！');
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 		END IF;
-- 		-- 记录流程
		INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
			SELECT new.erp_goods_cancel_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('修改核销单明细（编号：', new.id, '），配件（编号：', new.goodsId, '，二维码编号：'
			, new.erp_purchDetail_snCode_id, '），仓位（编号：', new.ers_shelfattr_id, '）。');
	END IF;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_goods_cancel_detail` FOR EACH ROW BEGIN

	DECLARE aCheck TINYINT;
	DECLARE msg VARCHAR(1000);

	SELECT a.isCheck INTO aCheck FROM erp_goods_cancel a WHERE a.id = old.erp_goods_cancel_id;

	IF old.outUserId > -1 THEN
		SET msg = CONCAT('该配件（二维码编号：', old.erp_purchDetail_snCode_id, '）已出仓完成，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		SET msg = CONCAT('配件核销单（编号：', old.erp_goods_cancel_id, '）已提交待审或审核通过，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 更新主表核销总价
	UPDATE erp_goods_cancel a SET a.priceSumCome = a.priceSumCome - old.packagePrice
	WHERE a.id = old.erp_goods_cancel_id;

	-- 记录流程
	INSERT INTO erp_goods_cancel_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT old.erp_goods_cancel_id, 'delete', old.lastModifiedId, old.lastModifiedEmpId, old.lastModifiedEmpName
		, old.lastModifiedBy, CONCAT('删除核销单明细（编号：', old.id, '），配件（编号：', old.goodsId, '，二维码编号：'
		, old.erp_purchDetail_snCode_id, '），仓位（编号：', old.ers_shelfattr_id, '）。');

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	配件核销状态表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_goods_cancel_bilwfw;
CREATE TABLE `erp_goods_cancel_bilwfw` (
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
  KEY `erp_goods_cancel_bilwfw_billId_idx` (`billId`),
  CONSTRAINT `fk_erp_goods_cancel_bilwfw_billId` FOREIGN KEY (`billId`) 
		REFERENCES `erp_goods_cancel` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='配件核销状态表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_goods_cancel_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goods_cancel_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_goods_cancel_bilwfw` FOR EACH ROW BEGIN
	set new.opTime = now()
		,new.memo = concat('员工（编号：', new.empId, ' 姓名：', new.empName, '）配件核销单（编号：', new.billId,'）'
			, new.name, IFNULL(new.said,' '));
END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_goods_cancel_shelfattr, 核销出仓
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_goods_cancel_shelfattr;
DELIMITER ;;
CREATE PROCEDURE p_goods_cancel_shelfattr(
	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, gccid  bigint(20) -- 核销单主表ID erp_goods_cancel.id
)
BEGIN

	DECLARE aCheck TINYINT;
	DECLARE aEmpId, aGoodsId, aErs_packageattr_id, aState, aStockState, aRoomId, gcid BIGINT(20);
	DECLARE aShelfId, aShelfBookId BIGINT(20);
	DECLARE aEmpName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);

	-- 判断用户是否合理
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作核销出仓！';
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	END IF;

	-- 获取核销明细信息
	SELECT b.id, b.isCheck
	INTO gcid, aCheck
	FROM erp_goods_cancel_detail a 
	INNER JOIN erp_goods_cancel b ON b.id = a.erp_goods_cancel_id
	WHERE a.erp_purchDetail_snCode_id = aid;

	-- 获取二维码信息
	SELECT a.goodsId, a.ers_packageattr_id, a.state, a.stockState, b.id, a.ers_shelfattr_id, a.ers_shelfbook_id
	INTO aGoodsId, aErs_packageattr_id, aState, aStockState, aRoomId, aShelfId, aShelfBookId
	FROM erp_purchdetail_sncode a 
	INNER JOIN ers_roomattr b ON b.id = a.roomId
	WHERE a.id = aid;

	-- 核销单是否合理
	IF ISNULL(aGoodsId) THEN
		SET msg = CONCAT('二维码（编号：', aid, '）不存在或该二维码对应的仓库不存在，不能核销出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(gcid) THEN
		SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）不存在核销单中，不能核销出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF gcid <> gccid THEN
		SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）与核销单号不对应，不能核销出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(aCheck) OR aCheck <> 1 THEN
		SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）对应的核销单没有审核通过，不能核销出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 判断二维码是否合理
	IF aState <> 1 THEN
		SET msg = concat('配件（编号：', aGoodsId, '，二维码编号：', aid, '）已出仓或者还没采购进仓，不能核销出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aStockState <> 0 THEN
		SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）已备货，不能核销出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aShelfBookId = -1 THEN
		SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）已被拆包，不能整体出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 判断是否能整体出仓
	if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.state = -1
		and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）包装存在低级包装出仓的记录，不能进行整体出仓');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS (select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
			where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.stockState = 1
				and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SET msg = CONCAT('配件（编号：', aGoodsId, '，二维码编号：', aid, '）包装存在低级包装备货的记录，不能进行整体出仓');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 根据二维码所在shelfBook位置判断是否需要拆包
	IF NOT EXISTS(SELECT 1 FROM erp_purchdetail_sncode a
		INNER JOIN ers_shelfbook b ON b.id = a.ers_shelfbook_id AND a.ers_packageattr_id = b.ers_packageattr_id
		WHERE a.id = aid) THEN
			CALL p_snCode_unpack(aid);
	END IF;

	SET msg = '核销出仓时，';

	-- 更新核销明细
	UPDATE erp_goods_cancel_detail a 
	SET a.lastModifiedId = uId, a.outUserId = uId
	WHERE a.erp_purchDetail_snCode_id = aid;
	if ROW_COUNT() <> 1 THEN
		set msg = concat(msg, '未能同步修改核销明细出仓人信息！') ;
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 修改二维码标志位
	UPDATE erp_purchDetail_snCode a , erp_purchDetail_snCode b 
	SET a.state = -1, a.ers_shelfbook_id = -1
	WHERE a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
		and b.id = aid and b.sSort = left(a.sSort, CHAR_LENGTH(b.sSort))
	;

	-- 判断该核销单主表包含的配件是否全部出仓，是则修改核销单主表的出仓完成员工
	IF NOT EXISTS(SELECT 1 FROM erp_goods_cancel_detail a 
		WHERE a.erp_goods_cancel_id = gcid AND ISNULL(a.outUserId)) THEN
			-- 更新配件核销主表出仓完成时间
			UPDATE erp_goods_cancel a 
			SET a.outUserId = uId, a.lastModifiedId = uId
			WHERE a.id = gcid;
			if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '出仓完成，未能同步修改核销主表出仓人信息！') ;
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
	END IF;

END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_goods_cancel_shelf, 更改商品仓位
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_call_goods_cancel_shelf;
DELIMITER ;;
CREATE PROCEDURE `p_call_goods_cancel_shelf`(
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, gcid  bigint(20) -- 核销单主表ID erp_goods_cancel.id
	, qty INT(11) -- 更改仓位商品个数
)
BEGIN
	DECLARE i INT DEFAULT 1;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;

	WHILE i < qty+1 DO
		CALL p_goods_cancel_shelfattr(ExtractValue(aids, '//a[$i]'), uId, gcid);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;