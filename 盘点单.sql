set foreign_key_checks = 0;

-- ----------------------------------------------------------------------------------------------------------------
-- 盘点单
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS ers_inventory;
CREATE TABLE `ers_inventory` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `ers_inventory_task_id` bigint(20) NOT NULL COMMENT '盘点任务编号',
  `isCheck` tinyint(4) DEFAULT '0' COMMENT '审核状态 -1:未提交或审核退回 0:提交待审 1:已审核',
  `goodsId` bigint(20) NOT NULL COMMENT '要盘点的商品',
  `ers_packageAttr_id` bigint(20) DEFAULT NULL COMMENT '商品的包装ID',
  `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '要盘点的仓位',
  `ers_roomattr_id` bigint(20) DEFAULT NULL COMMENT '要盘点的仓库',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `inventoryRecordUserId` bigint(20) DEFAULT NULL COMMENT '盘点录入用户ID',
  `inventoryRecordEmpId` bigint(20) DEFAULT NULL COMMENT '盘点录入员工ID',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '更新用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '更新员工ID',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `shelfQty` int(11) DEFAULT NULL COMMENT '仓位库存单品数量',
  `inventoryQty` int(11) DEFAULT NULL COMMENT '盘点单品数量',
  `differenceQty` int(11) DEFAULT 0 COMMENT '差异单品数量, 正数表示盘盈，负数表示盘亏',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `inventoryRecordDate` datetime DEFAULT NULL COMMENT '盘点录入时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `createdBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工用户名',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工姓名',
  `inventoryEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '盘点员工姓名',
  `inventoryRecordBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '盘点录入员工用户名',
  `inventoryRecordEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '盘点录入员工姓名',
  `lastModifiedBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工用户名',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工姓名',
  `checkBy` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核员工用户名',
  `checkEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核员工姓名',
  `code` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '盘点单号',
  `checkReason` varchar(255) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核原因',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `ers_inventory_ers_inventory_task_id_unique` (`ers_inventory_task_id`,`goodsId`,`ers_shelfattr_id`) USING BTREE,
  KEY `ers_inventory_goodsId_idx` (`goodsId`,`ers_shelfattr_id`) USING BTREE,
  KEY `ers_inventory_ers_shelfattr_id_idx` (`ers_shelfattr_id`),
  KEY `ers_inventory_code_idx` (`code`),
  CONSTRAINT `fk_ers_inventory_ers_inventory_task_id` FOREIGN KEY (`ers_inventory_task_id`) 
		REFERENCES `ers_inventory_task` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT `fk_ers_inventory_ers_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_ers_inventory_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) 
		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='盘点单'
;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_BEFORE_INSERT` BEFORE INSERT ON `ers_inventory` FOR EACH ROW
BEGIN

	DECLARE aid, sRoomId, aPackId bigint(20);
	DECLARE aName, aUserName, iTCode varchar(100);
	DECLARE iTCheck tinyint(4);
	DECLARE sQty int;

	-- 获取盘点任务表信息
	SELECT it.code, it.isCheck
	INTO iTCode, iTCheck
	FROM ers_inventory_task it WHERE it.id = new.ers_inventory_task_id;

	-- 判断盘点任务表审核状态
	IF iTCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表已进入审核流程，不能新增盘点单！';
	END IF;

	-- 获取商品仓位账簿库存
	SELECT SUM(s.qty) INTO sQty FROM ers_shelfbook s WHERE s.goodsId = new.goodsId AND s.ers_shelfattr_id = new.ers_shelfattr_id;
	-- 获取仓位所在仓库
	SELECT s.roomId INTO sRoomId FROM ers_shelfattr s WHERE s.id = new.ers_shelfattr_id;
	-- 获取包装ID
	SELECT p.id INTO aPackId FROM ers_packageattr p WHERE p.goodsId = new.goodsId AND p.degree = 1 LIMIT 1;

	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建盘点单时，必须指定最后更新员工！';
	elseif isnull(new.lastModifiedEmpId) then
		CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		SET new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName
			, new.creatorId = new.lastModifiedId, new.empId = aid, new.empName = aName, new.createdBy = aUserName;
	end if;

	-- 设置盘点单号
	SET new.code = CONCAT(iTCode, '-'
		, LPAD(
				IFNULL((SELECT MAX(RIGHT(i.code,4)) FROM ers_inventory i WHERE i.ers_inventory_task_id = new.ers_inventory_task_id),0)+1
			, 4, 0)
		);

	-- 判断仓位有效性
	IF ISNULL(sRoomId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请选择有效仓位！';
	END IF;

	-- 设置仓位库存和仓库
	SET new.ers_roomattr_id = sRoomId, new.shelfQty = IFNULL(sQty, 0), new.ers_packageAttr_id = aPackId;

END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_AFTER_INSERT` AFTER INSERT ON `ers_inventory` FOR EACH ROW
BEGIN

	insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.ers_inventory_task_id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy
	, concat('创建盘点单（编号：', new.id,'）');

END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_BEFORE_UPDATE` BEFORE UPDATE ON `ers_inventory` FOR EACH ROW
BEGIN

	DECLARE aid bigint(20);
	DECLARE aName, aUserName varchar(100);
	DECLARE iTCheck tinyint(4);
	DECLARE msg varchar(1000);
		
	-- 获取盘点任务表信息
	SELECT it.isCheck INTO iTCheck FROM ers_inventory_task it WHERE it.id = new.ers_inventory_task_id;

	SET msg = concat('盘点单（', new.code, '），');

	-- 判断盘点任务表审核状态
	IF iTCheck > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点任务表已审核通过，不能修改盘点单！';
	ELSEIF new.shelfQty <> old.shelfQty THEN
		SET msg = CONCAT(msg, '不能自行修改仓位库存！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	
	-- 更新最后修改员工信息
	CALL p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
	SET new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	
	IF new.isCheck = 1 AND old.isCheck = 0 THEN -- 审核通过
		-- 根据单据状态判断是否可以审核通过
		IF iTCheck <> 0 THEN
			SET msg = CONCAT('盘点任务表没有提交审核，', msg, '不能审核！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.inventoryQty < 0 OR ISNULL(new.inventoryQty) THEN
			SET msg = CONCAT(msg, '审核时，盘点数量不能为空，如果没有请填写0！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.creatorId = new.lastModifiedId THEN
			SET msg = CONCAT(msg, '审核时，不能由制表员工审核！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF ISNULL(new.inventoryEmpName) THEN
			SET msg = CONCAT(msg, '审核时，盘点员工不能为空！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.inventoryQty < 0 OR ISNULL(new.inventoryQty) OR new.inventoryQty <> old.inventoryQty THEN
			SET msg = CONCAT(msg, '审核时，不能修改盘点数量！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.checkUserId <> new.lastModifiedId THEN
			SET msg = CONCAT(msg, '审核时，操作人和最新操作人必须是同一人！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SET msg = CONCAT(msg, '审核时，不能更改盘点商品！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.ers_shelfattr_id <> old.ers_shelfattr_id THEN
			SET msg = CONCAT(msg, '审核时，不能更改盘点仓位！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录审核人
		SET new.checkEmpId = aid, new.checkEmpName = aName, new.checkBy = aUserName, new.checkTime = NOW();
		-- 计算差异单品数量
		SET new.differenceQty = new.inventoryQty - new.shelfQty;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.ers_inventory_task_id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('盘点单（', new.code, '）审核通过');
	ELSEIF new.isCheck = -1 AND old.isCheck = 0 THEN -- 审核退回
		-- 根据单据状态判断是否可以审核退回
		IF iTCheck <> 0 THEN
			SET msg = CONCAT('盘点任务表没有提交审核，', msg, '不能审核！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 		ELSEIF ISNULL(new.checkReason) OR new.checkReason = '' THEN
-- 			SET msg = CONCAT(msg, '审核退回时，必须指定退回原因！！');
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.creatorId = new.lastModifiedId THEN
			SET msg = CONCAT(msg, '审核时，不能由制表员工审核！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.inventoryQty <> old.inventoryQty THEN
			SET msg = CONCAT(msg, '审核时，不能修改盘点数量！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SET msg = CONCAT(msg, '审核时，不能更改盘点商品！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.ers_shelfattr_id <> old.ers_shelfattr_id THEN
			SET msg = CONCAT(msg, '审核时，不能更改盘点仓位！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name, said)
		select new.ers_inventory_task_id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
			, CONCAT('盘点单（', new.code, '）审核退回'), CONCAT(' （原因：', IFNULL(new.checkReason, ' '), '）');
	ELSEIF NOT ISNULL(new.inventoryQty) AND ISNULL(old.inventoryQty) THEN -- 填写盘点数量
		IF iTCheck > -1 THEN
			SET msg = CONCAT('盘点任务表已进入审核流程，', msg, '不能录入盘点数量！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF old.isCheck = 1 THEN
			SET msg = CONCAT(msg, '已审核通过，不能更改盘点数量！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.isCheck <> old.isCheck THEN
			SET msg = CONCAT(msg, '录入盘点数量时，不能审核！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.inventoryQty < 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效的盘点数量！';
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SET msg = CONCAT(msg, '录入盘点数量时，不能更改盘点商品！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.ers_shelfattr_id <> old.ers_shelfattr_id THEN
			SET msg = CONCAT(msg, '录入盘点数量时，不能更改盘点仓位！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF ISNULL(new.inventoryEmpName) THEN
			SET msg = CONCAT(msg, '录入盘点数量时，必须指定盘点员工！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录盘点记录人
		SET new.inventoryRecordEmpId = aid, new.inventoryRecordEmpName = aName, new.inventoryRecordBy = aUserName
			, new.inventoryRecordDate = NOW();
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.ers_inventory_task_id, 'recordInventoryQty', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('盘点单（', new.code, '）填写盘点数量（', new.inventoryQty, '）。');
	ELSEIF new.inventoryQty <> old.inventoryQty THEN -- 修改盘点数量
		IF iTCheck > -1 THEN
			SET msg = CONCAT('盘点任务表已进入审核流程，', msg, '不能修改盘点数量！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF old.isCheck = 1 THEN
			SET msg = CONCAT(msg, '已审核通过，不能更改盘点数量！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.isCheck <> old.isCheck THEN
			SET msg = CONCAT(msg, '修改盘点数量时，不能审核！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.inventoryQty < 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效的盘点数量！';
		ELSEIF old.goodsId > 0 AND new.goodsId <> old.goodsId THEN
			SET msg = CONCAT(msg, '更改盘点数量时，不能更改盘点商品！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.ers_shelfattr_id <> old.ers_shelfattr_id THEN
			SET msg = CONCAT(msg, '更改盘点数量时，不能更改盘点仓位！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF ISNULL(new.inventoryEmpName) THEN
			SET msg = CONCAT(msg, '更改盘点数量时，必须指定盘点员工！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.ers_inventory_task_id, 'changeInventoryQty', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, CONCAT('盘点单（', new.code, '）修改盘点数量（新：', new.inventoryQty
			, '，新：', old.inventoryQty,'）。');
	ELSE
		IF old.isCheck > 0 THEN
			SET msg = CONCAT(msg, '已审核通过，不能修改！！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 更换商品
		IF new.goodsId <> old.goodsId THEN
			SET new.ers_packageAttr_id = (SELECT p.id FROM ers_packageattr p WHERE p.goodsId = new.goodsId AND p.degree = 1 LIMIT 1);
		END IF;
		-- 记录操作状态
		insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.ers_inventory_task_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
			, new.lastModifiedBy, '自行修改';
	END IF;

END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_ers_inventory_BEFORE_DELETE`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_inventory_BEFORE_DELETE` BEFORE DELETE ON `ers_inventory` FOR EACH ROW
BEGIN

	DECLARE msg varchar(1000);
	DECLARE iTCheck tinyint(4);

	SET msg = concat('盘点单（', old.code, '），');

	-- 获取盘点任务表信息
	SELECT it.isCheck INTO iTCheck FROM ers_inventory_task it WHERE it.id = old.ers_inventory_task_id;

	-- 判断盘点任务表审核状态
	IF old.isCheck > 0 THEN
		SET msg = CONCAT(msg, '审核通过，不能删除！！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF iTCheck > -1 THEN
		SET msg = CONCAT(msg, '所属盘点任务表已进入审核流程，不能删除');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	-- 记录操作状态
	insert into ers_inventory_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select old.ers_inventory_task_id, 'delete', old.lastModifiedId, old.lastModifiedEmpId, old.lastModifiedEmpName
		, old.lastModifiedBy, CONCAT('删除盘点单（', old.code, '）。');
END;;
DELIMITER ;
-- ----------------------------------------------------------------------------------------------------------------