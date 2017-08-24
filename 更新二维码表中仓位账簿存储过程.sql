-- *****************************************************************************************************
-- 创建存储过程 p_sncode_unpack_set_shelfbook, 更新二维码的仓位账簿编号
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_sncode_unpack_set_shelfbook;
DELIMITER ;;
CREATE PROCEDURE p_sncode_unpack_set_shelfbook(
	aid BIGINT(20) -- 二维码编号 erp_purchdetail_sncode.id
)
BEGIN

	DECLARE aCount INT;
	DECLARE aSncodeId, sId, aPackageId, aShelfId BIGINT(20);

	SELECT COUNT(a.sncodeId) INTO aCount FROM erp_sncode_unpack a;

	WHILE aCount > 0 DO
		SET aCount = aCount - 1;

		-- 获取拆包后各个二维码的包装id和仓位id
		SELECT a.sncodeId, a.ers_packageattr_id, a.ers_shelfattr_id 
		INTO aSncodeId, aPackageId, aShelfId
		FROM erp_sncode_unpack a LIMIT aCount, 1;
		-- 获取上述操作的仓位账簿ID
		SELECT a.id INTO sId FROM ers_shelfbook a 
		WHERE a.ers_packageattr_id = aPackageId AND a.ers_shelfattr_id = aShelfId;
		-- update拆包后剩余包装的二维码仓位账簿ID
		update erp_purchDetail_snCode a, erp_purchDetail_snCode b 
		set a.ers_shelfbook_id = sId
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
			and b.id = aSncodeId and b.sSort = left(a.sSort, CHAR_LENGTH(b.sSort))
		;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能同步更新拆包后剩余包装二维码的仓位账簿变化！';
		end if;

	END WHILE;

	-- 将被拆包的父层二维码仓位账簿字段设置为-1
	UPDATE erp_purchdetail_sncode s, (
		select DISTINCT a.id, a.ers_packageattr_id, a.ers_shelfattr_id, a.qty, a.sSort
					from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
					where a.id = b.parentId 
					and c.id = aid and b.nLevel <= c.nLevel
					and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
					and a.ers_shelfbook_id > 0
		) b 
	SET s.ers_shelfbook_id = -1
	WHERE b.id = s.id
	;
	if ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能同步更改二维码拆包后被拆包的包装二维码仓位账簿编号！';
	end if;

END;;
DELIMITER ;