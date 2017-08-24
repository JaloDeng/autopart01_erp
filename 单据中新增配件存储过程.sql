-- *****************************************************************************************************
-- 创建存储过程 p_bill_create_part, 单据中新增存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_bill_create_part;
DELIMITER ;;
CREATE PROCEDURE p_bill_create_part(
	partCode varchar(100) -- 配件码，非空
	, partName varchar(100) -- 配件名
	, vehicleAs varchar(100) -- 车型
	, unit varchar(50) -- 单位
	, price decimal(20,4) -- 进货价
	, OUT gid bigint(20) -- 输出goodsId
	, OUT packId bigint(20)	-- 输出packageAttrId
)
BEGIN

	DECLARE pid bigint;
	DECLARE msg varchar(2000);

	-- 判断输入配件码是否存在
	IF ISNULL(partCode) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增配件时，必须指定配件码';
	ELSEIF EXISTS(SELECT 1 FROM erp_goods g WHERE g.partCode = partCode) THEN
		SET msg = CONCAT('配件码（',partCode,'）已存在，不能重复添加！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取该配件码所在配件资料库中主键编号
	SELECT p.id INTO pid FROM autopart01_modeldb.erv$vhcl_part p WHERE p.`code` = partCode;

	-- 配件库不存在该配件码
	IF ISNULL(pid) THEN
		-- 向资料库新增配件
		INSERT INTO autopart01_modeldb.erv$vhcl_part (code, name, vehicleAs, unit, createMemo)
		SELECT partCode, partName, vehicleAs, IFNULL(unit,'个'), '在单据中添加';
		-- 获取主键编号
		SET pid = LAST_INSERT_ID();
	END IF;

	-- 向goods表新增配件
	INSERT INTO erp_goods(itemId, partCode, vehicleAs, name, unit)
	SELECT pid, partCode, vehicleAs, partName, IFNULL(unit,'个');
	-- 获取主键编号
	SET gid = LAST_INSERT_ID();
	-- 获取包装主键编号
	SET packId = (SELECT p.id FROM ers_packageattr p WHERE p.goodsId = gid);
	-- 判断是否输入进价
	IF price > 0 THEN
		-- 写入进价
		UPDATE ers_packageattr p SET p.newPrice = price, p.minPrice = price, p.maxPrice = price, p.packageUnit = unit
		WHERE p.id = packId;
	ELSEIF price < 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效价钱！';
	END IF;

END;;
DELIMITER ;