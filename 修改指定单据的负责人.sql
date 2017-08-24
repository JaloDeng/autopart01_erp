-- *****************************************************************************************************
-- 创建存储过程 p_change_bill_userId, 修改指定单据的负责人
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_change_bill_userId;
DELIMITER ;;
CREATE PROCEDURE p_change_bill_userId(
	aid bigint(20) -- 询价单号或销售单号
	, uid BIGINT(20) -- 当前操作用户id autopart01_security.sec$staff.userId
	, cid bigint(20)	-- 指定新负责用户ID autopart01_security.sec$staff.userId
	, tid TINYINT(4) -- 类型，1：询价单(客服)，2：报价单(跟单)，3：销售单(客服)，4：采购单(跟单)
)
BEGIN

	DECLARE aCheck TINYINT(4);
	DECLARE uEmpId, cEmpId, aUserId BIGINT(20);
	DECLARE uName, uUserName, cName, cUserName VARCHAR(100);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- 开启事务
	START TRANSACTION;

	-- 获取操作用户信息
	CALL p_get_userInfo(uid, uEmpId, uName, uUserName);
	-- 获取新指定用户信息
	CALL p_get_userInfo(cid, cEmpId, cName, cUserName);

	IF tid = 1 THEN -- 修改询价报价单负责的客服
		-- 获取询价报价单相关信息
		SELECT ib.ischeck, ib.creatorId INTO aCheck, aUserId FROM erp_inquiry_bil ib WHERE ib.id = aid;
		-- 根据询价报价单相关信息判断是否能更改负责该单客服
		IF aCheck <> 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该询价单已转为销售订单，不能修改该单的客服员工！';
		ELSEIF aUserId = cid THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新的客服员工不能与旧的客服员工相同！';
		END IF;
		-- 更改询价报价单的客服员工
		UPDATE erp_inquiry_bil ib SET ib.creatorId = cid, ib.lastModifiedId = uid WHERE ib.id = aid;
-- 	ELSEIF tid = 2 THEN -- 修改询价报价单负责的跟单
-- 		-- 获取询价报价单相关信息
-- 		SELECT ib.ischeck, ib.updaterId INTO aCheck, aUserId FROM erp_inquiry_bil ib WHERE ib.id = aid;
-- 		-- 根据询价报价单相关信息判断是否能更改负责该单客服
-- 		IF aCheck <> 0 THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该询价单已转为销售订单，不能修改该单的负责报价员工！';
-- 		ELSEIF aUserId = cid THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新的报价员工不能与旧的报价员工相同！';
-- 		END IF;
-- 		-- 更改询价报价单的报价员工
-- 		UPDATE erp_inquiry_bil ib SET ib.updaterId = cid, ib.lastModifiedId = uid WHERE ib.id = aid;
	ELSEIF tid = 3 THEN -- 修改销售订单负责的客服
		-- 获取销售订单相关信息
		SELECT vb.isCheck, vb.creatorId INTO aCheck, aUserId FROM erp_vendi_bil vb WHERE vb.id = aid;
		-- 根据询价报价单相关信息判断是否能更改负责该单客服
		IF aCheck <> -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单已进入审核流程，不能修改该单的客服员工！';
		ELSEIF aUserId = cid THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新的客服员工不能与旧的客服员工相同！';
		END IF;
		-- 更新销售订单的客服员工
		UPDATE erp_vendi_bil vb SET vb.creatorId = cid, vb.lastModifiedId = uid WHERE vb.id = aid;
	ELSEIF tid = 4 THEN -- 修改采购订单负责的跟单
		-- 获取采购订单相关信息
		SELECT pb.isCheck, pb.creatorId INTO aCheck, aUserId FROM erp_purch_bil pb WHERE pb.id = aid;
		-- 根据采购订单相关信息判断是否能更改负责该单跟单
		IF aCheck <> -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单已进入审核流程，不能修改该单的跟单员工！';
		ELSEIF aUserId = cid THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新的跟单员工不能与旧的跟单员工相同！';
		END IF;
		-- 更新采购订单的跟单员工
		UPDATE erp_purch_bil pb SET pb.creatorId = cid, pb.lastModifiedId = uid WHERE pb.id = aid;
	ELSEIF tid = 5 THEN -- 修改销售退货单负责的客服
		-- 获取销售退货单相关信息
		SELECT vb.isCheck, vb.creatorId INTO aCheck, aUserId FROM erp_vendi_back vb WHERE vb.id = aid;
		-- 根据销售退货单相关信息判断是否能更改负责该单客服
		IF aCheck <> -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售退货单已进入审核流程，不能修改该单的客服员工！';
		ELSEIF aUserId = cid THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新的客服员工不能与旧的客服员工相同！';
		END IF;
		-- 更新销售退货单的客服员工
		UPDATE erp_vendi_back vb SET vb.creatorId = cid, vb.lastModifiedId = uid WHERE vb.id = aid;
	ELSEIF tid = 6 THEN -- 修改采购退货单负责的跟单
		-- 获取采购退货单相关信息
		SELECT pb.isCheck, pb.creatorId INTO aCheck, aUserId FROM erp_purch_back pb WHERE pb.id = aid;
		-- 根据采购退货单相关信息判断是否能更改负责该单跟单
		IF aCheck <> -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购退货单已进入审核流程，不能修改该单的跟单员工！';
		ELSEIF aUserId = cid THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新的跟单员工不能与旧的跟单员工相同！';
		END IF;
		-- 更新采购退货单的跟单员工
		UPDATE erp_purch_back pb SET pb.creatorId = cid, pb.lastModifiedId = uid WHERE pb.id = aid;
	END if;

	-- 提交
	COMMIT;

END;;
DELIMITER ;