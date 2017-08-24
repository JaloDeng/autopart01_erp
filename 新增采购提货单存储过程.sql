-- *****************************************************************************************************
-- 创建存储过程 p_vendi_stock_shelfattr, 申请提货:新增采购提货单
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_add_purch_pick;
DELIMITER ;;
CREATE PROCEDURE p_add_purch_pick(
	pid bigint(20) -- 采购订单ID，erp_purch_bil.id
	, uId bigint(20) -- 用户ID  autopart01_security.sec$staff.userId
	, OUT purchPickId bigint(20) -- 采购提货单编号 erp_purch_pick.id
)
BEGIN

	DECLARE aEmpId, aUserId, aSupplierId, aPayId BIGINT(20);
	DECLARE aCheck, aReceive TINYINT;
	DECLARE aEmpName, aUserName, aPurchCode, aInquiryCode VARCHAR(100);
	DECLARE aTakeGeoTel VARCHAR(1000);
	DECLARE aApplyTime datetime;

	-- 获取用户相关信息
	CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);

	-- 获取采购订单状态
	SELECT p.isCheck, p.isReceive, p.inUserId, p.supplierId, p.takeGeoTel, p.erp_payment_type_id, p.applyPickTime, p.purchCode, p.inquiryCode 
	INTO aCheck, aReceive, aUserId,  aSupplierId, aTakeGeoTel, aPayId, aApplyTime, aPurchCode, aInquiryCode
	FROM erp_purch_bil p WHERE p.id = pid;
	-- 根据采购订单状态判断是否可以申请提货
	IF ISNULL(aSupplierId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单不存在或没有选择汽配供应商，不能申请提货！';
	ELSEIF aUserId > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单配件已全部进仓，不能申请提货！';
	ELSEIF aReceive <> 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单仓库已签收，不能申请提货！';
	ELSEIF aCheck <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单没有审核通过，不能申请提货！';
	END IF;

	-- 采购单提货申请时间为空时新增提货单
	IF aApplyTime > 0 THEN
		-- 获取采购单对应的提货单编号
		SELECT pp.id INTO purchPickId FROM erp_purch_pick pp WHERE pp.erp_purch_bil_id = pid;
	ELSE
		-- 生成采购提货单
		INSERT INTO erp_purch_pick(erp_purch_bil_id, supplierId, userId, empId, userName, empName
			, opTime, lastModifiedId, lastModifiedDate, takeGeoTel, erp_payment_type_id, purchCode, inquiryCode)
		SELECT pid, aSupplierId, uId, aEmpId, aUserName, aEmpName
			, NOW(), uId, NOW(), aTakeGeoTel, aPayId, aPurchCode, aInquiryCode;
		if ROW_COUNT() <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '申请采购提货时，无法生成采购提货单！';
		end if;

		-- 将新增采购提货单的编号返回代码
		SELECT LAST_INSERT_ID() INTO purchPickId;
		-- 更新采购订单申请提货时间
		UPDATE erp_purch_bil p SET p.applyPickTime = NOW(), p.lastModifiedId = uId WHERE p.id = pid;
	END IF;

END;;
DELIMITER ;