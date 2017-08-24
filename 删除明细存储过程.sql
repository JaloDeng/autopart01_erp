-- *****************************************************************************************************
-- 创建存储过程 p_call_merge_purch, 合并采购单
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_cancel_detail;
DELIMITER ;;
CREATE PROCEDURE `p_cancel_detail`(
		did bigint(20) -- 明细编号
	, tid TINYINT(4) -- 类型ID,1:销售明细,2:采购明细
	, uid bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
)
BEGIN

	DECLARE aCheck, aCost, aSubmit TINYINT(4);
	DECLARE uEmpId BIGINT(20);
	DECLARE sTime, oTime datetime;
	DECLARE uName, uUserName VARCHAR(100);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	-- 获取操作用户信息
	CALL p_get_userInfo(uid, uEmpId, uName, uUserName);

	-- 开启事务
	START TRANSACTION;

	IF tid = 1 THEN -- 删除销售明细

		-- 获取销售单、明细状态
		SELECT vb.isCheck, vb.isCost, vb.isSubmit, sd.stockTime, sd.outTime
		INTO aCheck, aCost, aSubmit, sTime, oTime
		FROM erp_sales_detail sd INNER JOIN erp_vendi_bil vb ON vb.id = sd.erp_vendi_bil_id WHERE sd.id = did;
		IF aCheck > -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售订单已进入审核流程，不能删除！';
		ELSEIF aCost > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售订单已收款确认，不能删除！';
		ELSEIF aSubmit > -1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售订单已进入出仓流程，不能删除！';
		ELSEIF sTime > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '配件已备货，不能删除！';
		ELSEIF oTime > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '配件已出仓，不能删除！';
		END IF;
		-- 删除明细
		DELETE sd FROM erp_sales_detail sd WHERE sd.id = did;

	END IF;

	COMMIT;  

END;;
DELIMITER ;