set foreign_key_checks = 0;

-- ----------------------------------------------------------------------------------------------------------------
-- 盘点任务表
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS ers_inventory_task;
CREATE TABLE `ers_inventory_task` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `ers_inventory_type_id` int DEFAULT NULL COMMENT '盘点类型',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '审核状态 -1:未提交或审核退回 0:提交待审 1:已审核',
  `goodsId` bigint(20) DEFAULT NULL COMMENT '要盘点的商品',
  `vehicleAs` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '要盘点的车型',
  `supplierId` bigint(20) DEFAULT NULL COMMENT '要盘点的供应商',
  `ers_roomattr_id` bigint(20) DEFAULT NULL COMMENT '要盘点的仓库',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '更新用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '更新员工ID',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `inTime` datetime DEFAULT NULL COMMENT '进仓完成时间',
  `sncodeTime` datetime DEFAULT NULL COMMENT '生码时间',
  `createdBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工用户名',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工姓名',
  `lastModifiedBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工用户名',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工姓名',
  `checkEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核人',
  `code` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '盘点任务单号',
  `checkReason` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核原因',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `ers_inventory_task_ers_inventory_type_id_idx` (`ers_inventory_type_id`),
  KEY `ers_inventory_task_isCheck_idx` (`isCheck`),
  KEY `ers_inventory_task_goodsId_idx` (`goodsId`),
  KEY `ers_inventory_task_ers_roomattr_id_idx` (`ers_roomattr_id`),
  KEY `ers_inventory_task_code_idx` (`code`),
  CONSTRAINT `fk_ers_inventory_task_ers_inventory_type_id` FOREIGN KEY (`ers_inventory_type_id`) 
		REFERENCES `ers_inventory_type` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='盘点任务表'
;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_task_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_task_BEFORE_INSERT` BEFORE INSERT ON `ers_inventory_task` FOR EACH ROW
BEGIN

	DECLARE aid bigint(20);
	DECLARE aName, aUserName varchar(100);

	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建盘点任务表时，必须指定最后更新员工！';
	elseif isnull(new.lastModifiedEmpId) then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName
			, new.creatorId = new.lastModifiedId, new.empId = aid, new.empName = aName, new.createdBy = aUserName;
	end if;

	-- 生成code PD+8位日期+4位员工id+4位流水
	set new.code = concat('PD', date_format(NOW(),'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from ers_inventory_task a 
				where date(a.createdDate) = date(NOW()) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);

END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_task_BAFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_task_AFTER_INSERT` AFTER INSERT ON `ers_inventory_task` FOR EACH ROW
BEGIN

	insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy
	, concat('创建盘点任务表（编号：', new.id,'）');

END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_task_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_task_BEFORE_UPDATE` BEFORE UPDATE ON `ers_inventory_task` FOR EACH ROW
BEGIN

	DECLARE aid bigint(20);
	DECLARE aName, aUserName varchar(100);

	-- 最后修改用户变更，获取相关信息
	CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
	SET new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;

	IF new.inTime > 0 AND ISNULL(old.inTime) THEN -- 进仓完成
		IF ISNULL(old.sncodeTime) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表没有生码，不能完成进仓！！';
		ELSEIF old.isCheck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表没有审核通过，不能完成进仓！！';
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'in', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '进仓完成';
	ELSEIF new.sncodeTime > 0 AND ISNULL(old.sncodeTime) THEN	-- 批量生码
		-- 根据单据状态判断是否可以生码
		IF new.isCheck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表没有审核完成，不能生成二维码！！';
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'code', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '配件生码';
	ELSEIF new.isCheck = 1 AND old.isCheck = 0 THEN -- 审核通过
		-- 根据单据状态判断是否可以审核通过
		IF new.creatorId = new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能由制表员工审核！！';
		ELSEIF new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，操作人和最新操作人必须是同一人！';
		ELSEIF new.ers_inventory_type_id <> old.ers_inventory_type_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点任务确认方式！';
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点商品！';
		ELSEIF NOT ISNULL(old.vehicleAs) AND new.vehicleAs <> old.vehicleAs THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点车型！';
		ELSEIF old.supplierId > 0 AND new.supplierId <> old.supplierId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点供应商！';
		ELSEIF old.ers_roomattr_id > 0 AND new.ers_roomattr_id <> old.ers_roomattr_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点仓库！';
		END IF;
		-- 记录审核人
		SET new.checkEmpId = new.lastModifiedEmpId, new.checkEmpName = new.lastModifiedEmpName, new.checkTime = NOW();
		-- 判断盘点单是否存在没有审核通过的
		IF EXISTS(SELECT 1 FROM ers_inventory i WHERE i.ers_inventory_task_id = new.id AND i.isCheck <> 1 LIMIT 1) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，存在没有审核的盘点单！';
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '审核通过';
	ELSEIF new.isCheck = -1 AND old.isCheck = 0 THEN -- 审核退回
		-- 根据单据状态判断是否可以审核不通过
		IF ISNULL(new.checkReason) OR new.checkReason = '' THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核退回时，必须指定退回原因！！';
		ELSEIF new.creatorId = new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能由制表员工审核！！';
		ELSEIF new.ers_inventory_type_id <> old.ers_inventory_type_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点任务确认方式！';
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点商品！';
		ELSEIF NOT ISNULL(old.vehicleAs) AND new.vehicleAs <> old.vehicleAs THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点车型！';
		ELSEIF old.supplierId > 0 AND new.supplierId <> old.supplierId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点供应商！';
		ELSEIF old.ers_roomattr_id > 0 AND new.ers_roomattr_id <> old.ers_roomattr_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表审核时，不能更改盘点仓库！';
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name, said)
		select new.id, 'checkedBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
			, '审核退回', CONCAT(' （原因：', IFNULL(new.checkReason, ' '), '）');
	ELSEIF new.isCheck = 0 AND old.isCheck = -1 THEN -- 提交待审
		-- 根据单据状态判断是否可以提交审核
		IF new.ers_inventory_type_id <> old.ers_inventory_type_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表提交审核时，不能更改盘点任务确认方式！';
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表提交审核时，不能更改盘点商品！';
		ELSEIF NOT ISNULL(old.vehicleAs) AND new.vehicleAs <> old.vehicleAs THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表提交审核时，不能更改盘点车型！';
		ELSEIF old.supplierId > 0 AND new.supplierId <> old.supplierId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表提交审核时，不能更改盘点供应商！';
		ELSEIF old.ers_roomattr_id > 0 AND new.ers_roomattr_id <> old.ers_roomattr_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表提交审核时，不能更改盘点仓库！';
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'submitCheck', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '提交待审';
	ELSE
		IF old.isCheck > -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表已进入审核流程，不能修改！！';
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy, '自行修改';
	END IF;

END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- -- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_task_AFTER_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_task_AFTER_UPDATE` AFTER UPDATE ON `ers_inventory_task` FOR EACH ROW
BEGIN

	IF new.isCheck = 1 AND old.isCheck = 0 THEN -- 审核通过
		-- 生成采购单，按盘点单盘盈情况生成，一张盘点单对应一张采购单
		INSERT INTO erp_purch_bil(ers_inventory_id, erp_payment_type_id, supplierId, zoneNum, isCheck
			, lastModifiedId, erc$telgeo_contact_id, applyPickTime, memo, purchCode)
		SELECT i.id, 1, 1, '020', -1
			, new.lastModifiedId, 1, NOW(), '由盘点单自动生成', i.code
		FROM ers_inventory i WHERE i.ers_inventory_task_id = new.id AND i.differenceQty > 0
		;
		-- 生成采购明细，按盘点单盘盈情况生成，一张明细对应一张采购单、盘点单
		INSERT INTO erp_purch_detail(isReceive, erp_purch_bil_id, goodsId, supplierId
			, ers_packageAttr_id, packageQty, packageUnit, unit
			, packagePrice, costTime, lastModifiedId)
		SELECT 1, pb.id, i.goodsId, 1
			, i.ers_packageAttr_id, i.differenceQty, '件', '件'
			, 0, NOW(), new.lastModifiedId
		FROM ers_inventory i
		INNER JOIN erp_purch_bil pb ON pb.ers_inventory_id = i.id
		WHERE i.ers_inventory_task_id = new.id AND i.differenceQty > 0
		;
		-- 更新采购单审核字段，由-1变为1
		UPDATE erp_purch_bil pb INNER JOIN ers_inventory i ON i.id = pb.ers_inventory_id 
		SET pb.isCheck = 1, pb.isReceive = 1, pb.isCost = 1 
			, pb.checkUserId = new.lastModifiedId, pb.checkEmpId = new.lastModifiedEmpId, pb.checkEmpName = new.lastModifiedEmpName
			, pb.costUserId = new.lastModifiedId, pb.costEmpId = new.lastModifiedEmpId, pb.costEmpName = new.lastModifiedEmpName
			, pb.checkTime = NOW(), pb.costTime = NOW()
		WHERE i.ers_inventory_task_id = new.id AND i.differenceQty > 0;
		
	END IF;

END;;
DELIMITER ;
-- -- ----------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_task_BEFORE_DELETE`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_task_BEFORE_DELETE` BEFORE DELETE ON `ers_inventory_task` FOR EACH ROW
BEGIN
	-- 判断盘点任务表审核状态
	IF old.isCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表已进入审核流程，不能删除！！';
	END IF;
	-- 判断盘点单是否存在审核通过
	IF EXISTS(SELECT 1 FROM ers_inventory i WHERE i.ers_inventory_task_id = old.id AND i.isCheck = 1 LIMIT 1) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '存在审核通过的盘点单，不能删除！';
	END IF;
	-- 删除盘点单
	DELETE FROM ers_inventory WHERE ers_inventory_task_id = old.id;
	-- 删除盘点状态流程表
	DELETE FROM ers_inventory_bilwfw WHERE billId = old.id;
END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- 	---------------------------------------------------------------------------------------------------------------
-- 	盘点状态流程表
-- 	---------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS ers_inventory_bilwfw;
CREATE TABLE `ers_inventory_bilwfw` (
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
  KEY `ers_inventory_bilwfw_userId_idx` (`userId`),
  KEY `ers_inventory_bilwfw_billStatus_idx` (`billStatus`),
  KEY `ers_inventory_bilwfw_opTime_idx` (`opTime`),
  KEY `ers_inventory_bilwfw_billId_idx` (`billId`),
  CONSTRAINT `fk_ers_inventory_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `ers_inventory_task` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='盘点状态表'
;

-- 	---------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_ers_inventory_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `ers_inventory_bilwfw` FOR EACH ROW BEGIN
	set new.opTime = now()
		, new.memo = concat('员工（编号：', IFNULL(new.empId,' '), ' 姓名：', IFNULL(new.empName,' ')
		, '）盘点任务表（编号：', IFNULL(new.billId,' '),'）', IFNULL(new.name,' '), IFNULL(new.said,' '));
END;;
DELIMITER ;
-- 	---------------------------------------------------------------------------------------------------------------