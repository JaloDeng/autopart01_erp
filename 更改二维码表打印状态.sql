-- *****************************************************************************************************
-- 创建存储过程 p_purchdetail_sncode_print, 更改二维码表打印状态
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_purchdetail_sncode_print;
DELIMITER ;;
CREATE PROCEDURE p_purchdetail_sncode_print(
	aid bigint(20) -- 二维码表编号 erp_purchdetail_sncode.id
	, uid BIGINT(20) -- 当前操作用户id autopart01_security.sec$staff.userId
	, tid TINYINT(4) -- 类型，0：撤销打印状态，1：打印
)
BEGIN

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- 开启事务
	START TRANSACTION;

	-- 判断用户是否有效
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.`sec$user` u WHERE u.ID = uid) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效员工打印！';
	END IF;

	IF tid = 0 THEN -- 撤销打印
		-- 判断该二维码是否已打印
		IF EXISTS(SELECT 1 FROM erp_purchdetail_sncode pds WHERE pds.id = aid AND pds.isPrint = 0) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该二维码还没打印，不能撤销打印状态！';
		ELSE
			-- 更改二维码打印状态
			UPDATE erp_purchdetail_sncode pds SET pds.isPrint = 0 WHERE pds.id = aid;
		END IF;
	ELSEIF tid = 1 THEN -- 打印
		-- 判断该二维码是否已打印
		IF EXISTS(SELECT 1 FROM erp_purchdetail_sncode pds WHERE pds.id = aid AND pds.isPrint = 1) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该二维码已打印，不能重复打印！';
		ELSE
			-- 更改二维码打印状态
			UPDATE erp_purchdetail_sncode pds SET pds.isPrint = 1 WHERE pds.id = aid;
		END IF;
	END IF;

	-- 提交
	COMMIT;

END;;
DELIMITER ;