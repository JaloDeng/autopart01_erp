SET FOREIGN_KEY_CHECKS =0;

-- -----------------------------------------------------------------------------------------------------
-- 更改仓位操作记录表
-- -----------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_goods_change_shelf`;
CREATE TABLE `erp_goods_change_shelf`(
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
	`snCodeId` bigint(20) NOT NULL COMMENT '货物二维码编码',
	`goodsId` bigint(20) NOT NULL COMMENT 'erp_goods.id',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
	`empId` bigint(20) DEFAULT NULL COMMENT '员工编码',
  `oldRoomId` bigint(20) DEFAULT NULL COMMENT '原仓库编码',
	`oldShelfId` bigint(20) NOT NULL COMMENT '原仓位编码',
	`newRoomId` bigint(20) DEFAULT NULL COMMENT '新仓库编码',
	`newShelfId` bigint(20) NOT NULL COMMENT '新仓位编码',
	`userName` VARCHAR(100) DEFAULT NULL COMMENT '用户名称',
  `empName` VARCHAR(100) DEFAULT NULL COMMENT '员工名称',
	`opTime` datetime DEFAULT NULL COMMENT '日期时间',
	PRIMARY KEY (`id`),
	KEY `goods_change_operation_snCodeId_idx` (`snCodeId`),
  KEY `goods_change_operation_goodsId_idx` (`goodsId`),
	KEY `goods_change_operation_userId_idx` (`userId`),
  KEY `goods_change_operation_oldRoomId_idx` (`oldRoomId`),
  KEY `goods_change_operation_oldShelfId_idx` (`oldShelfId`),
	KEY `goods_change_operation_newRoomId_idx` (`newRoomId`),
  KEY `goods_change_operation_newShelfId_idx` (`newShelfId`),
	KEY `goods_change_operation_empName_idx` (`empName`),
  KEY `goods_change_operation_opTime_idx` (`opTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='修改货物仓位记录表'
;

-- *****************************************************************************************************
-- 创建存储过程 p_goods_change_shelfattr, 更改商品仓位
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_goods_change_shelfattr`;
DELIMITER ;;
CREATE PROCEDURE `p_goods_change_shelfattr`(
	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, shelfattrId bigint(20) -- 新货架ID ers_packageAttr_id
)
BEGIN

	DECLARE nRoomId, oRoomId, oShelfattrId, oGoodsId, aErs_packageattr_id, aShelfbookId BIGINT(20);
	DECLARE pdId, aEmpId BIGINT(20);
	DECLARE oQty INT;
	DECLARE aEmpName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);
	DECLARE aState, aStockState TINYINT;

	SET msg = '修改货物仓位：';

	-- 获取有效用户
	IF EXISTS(SELECT 1 FROM autopart01_security.`sec$user` a WHERE a.ID = uId) THEN
		call p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该用户不存在，不能更换仓位！！';
	END IF;

	-- 获取货物二维码旧仓位信息
	SELECT a.roomId, a.ers_shelfattr_id, a.qty, a.goodsId, a.ers_packageattr_id
	INTO oRoomId, oShelfattrId, oQty, oGoodsId, aErs_packageattr_id
	FROM erp_purchdetail_sncode a WHERE a.id = aid;

	-- 新仓位不能与旧仓位相同
	IF oShelfattrId = shelfattrId THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '配件更换仓位时，新仓位不能与旧仓位相同！！';
	END IF;

	-- 获取新仓位的信息
	SELECT a.roomId INTO nRoomId FROM ers_shelfattr a WHERE a.id = shelfattrId;
	IF ISNULL(nRoomId) THEN
		SET msg = concat('指定的仓位（编号：', shelfattrId,'）不存在，不能更换仓位！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取二维码状态
	SELECT a.state, a.erp_purch_detail_id, a.stockState, a.ers_shelfbook_id 
	INTO aState, pdId, aStockState, aShelfbookId
	FROM erp_purchdetail_sncode a WHERE a.id = aid;

	-- 根据二维码状态判断是否可以更换仓位
	IF ISNULL(pdId) OR pdId < 1 THEN 
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该货物二维码不存在，不能更换仓位！！';
	ELSEIF aState <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该货物二维码还没进仓或已经出仓，不能更换仓位！！';
	ELSEIF aStockState <> 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该货物二维码处于备货状态，不能更换仓位！！';
	ELSEIF aShelfbookId = -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该货物二维码已被拆包，不能更换仓位！！';
	END IF;

	-- 判断二维码或低级包装中二维码是否处于核销状态
	IF EXISTS(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_goods_cancel_detail c 
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort AND c.erp_purchDetail_snCode_id = a.id LIMIT 1) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装处于核销状态或已核销出仓，不能进行更换仓位！';
	END IF;

	-- 判断二维码的包装在ers_shelfbook表中是否存在，不存在要进行拆包操作
	IF NOT EXISTS(SELECT 1 FROM erp_purchdetail_sncode a
		INNER JOIN ers_shelfbook b ON b.id = a.ers_shelfbook_id AND a.ers_packageattr_id = b.ers_packageattr_id
		WHERE a.id = aid) THEN
			call p_snCode_unpack(aid);
	END IF;

	-- 更改shelfBook账簿
	-- 减去旧仓位数量
	update ers_shelfBook a 
	set a.packageQty = a.packageQty - 1, a.qty = a.qty - oQty
	where a.ers_packageattr_id = aErs_packageattr_id and a.ers_shelfattr_id = oShelfattrId;
	if ROW_COUNT() <> 1 THEN
		set msg = concat(msg, '未能同步修改旧仓位账簿库存！') ;
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 添加新仓位数量
	IF EXISTS(SELECT 1 FROM ers_shelfbook a 
		WHERE a.ers_packageattr_id = aErs_packageattr_id AND a.ers_shelfattr_id = shelfattrId
	) THEN
		update ers_shelfBook a 
		set a.packageQty = a.packageQty + 1, a.qty = a.qty + oQty
		where a.ers_packageattr_id = aErs_packageattr_id and a.ers_shelfattr_id = shelfattrId;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能同步修改新仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
	ELSE
		insert into ers_shelfBook(goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty) 
		select oGoodsId, aErs_packageattr_id, nRoomId, shelfattrId, 1, oQty;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '未能同步修改新仓位账簿库存！') ;
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;
	END IF;

	-- 获取新仓位账簿id
	SELECT a.id INTO aShelfbookId
	FROM ers_shelfbook a WHERE a.ers_packageattr_id = aErs_packageattr_id AND a.ers_shelfattr_id = shelfattrId;
	-- 更换该二维码及子二维码的仓库、仓位、仓位账簿id
	UPDATE erp_purchDetail_snCode a , erp_purchDetail_snCode b 
	SET a.ers_shelfattr_id = shelfattrId, a.roomId = nRoomId, a.ers_shelfbook_id = aShelfbookId
	WHERE a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
		and b.id = aid and b.sSort = left(a.sSort, CHAR_LENGTH(b.sSort))
	;
	IF ROW_COUNT() = 0 THEN
			set msg = CONCAT(msg, '更换货物（二维码编号：', aid, '）仓位时出错！') ;  
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg; 
	END IF;

	-- 记录操作
	INSERT INTO erp_goods_change_shelf 
		(snCodeId, goodsId, userId, empId, oldRoomId, oldShelfId, newRoomId, newShelfId, userName, empName, opTime)
		SELECT aid, oGoodsId, uId, aEmpId, oRoomId, oShelfattrId, nRoomId, shelfattrId, aUserName, aEmpName, NOW()
	;
	IF ROW_COUNT() <> 1 THEN
			set msg = CONCAT(msg, '更换货物（二维码编号：', aid, '）仓位时，不能记录操作！') ;  
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg; 
	END IF;

END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_goods_change_shelf, 更改商品仓位
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_call_goods_change_shelf`;
DELIMITER ;;
CREATE PROCEDURE `p_call_goods_change_shelf`(
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, shelfattrId bigint(20) -- 新货架ID ers_packageAttr_id
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
		CALL p_goods_change_shelfattr(ExtractValue(aids, '//a[$i]'), uId, shelfattrId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;