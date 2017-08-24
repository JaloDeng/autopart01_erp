-- *****************************************************************************************************
-- 创建存储过程 p_inventory_snCode, 盘点任务单生码
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_inventory_snCode;
DELIMITER ;;
CREATE PROCEDURE p_inventory_snCode(
	itid bigint(20) -- 盘点任务单编号 ers_inventory_task.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
)
BEGIN

	DECLARE aCheck tinyint(4);
	DECLARE aCount, qty, degree, actualQty int;
	DECLARE aSupplierId, erp_purch_detail_id, gId, ers_packageAttr_id, pid bigint;
	DECLARE msg varchar(2000);
	DECLARE str VARCHAR(10000);
	DECLARE aSnCodeTime datetime;

	-- 获取盘点任务单信息
	SELECT it.isCheck, it.sncodeTime
	INTO aCheck, aSnCodeTime
	FROM ers_inventory_task it 
	WHERE it.id = itid;
	-- 根据盘点任务表状态是否可以生码
	IF ISNULL(aCheck) THEN
		SET msg = concat('盘点任务表不存在，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSnCodeTime > 0 THEN
		SET msg = concat('盘点任务表已生码，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck <> 1 THEN
		SET msg = concat('盘点任务表没有审核完成，不能完成生码操作');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	-- 设置计数器
	SET @xh = 0;
	-- 清空临时表数据
	DELETE FROM erp_purch_detail_temp;
	-- 写入临时表
	INSERT INTO erp_purch_detail_temp(id, erp_purch_detail_id, goodsId, ers_packageAttr_id, qty, degree)
	SELECT (@xh:=@xh+1) AS id, pd.id AS erp_purch_detail_id, pd.goodsId, pd.ers_packageAttr_id, pd.packageQty, p.degree
	FROM ers_inventory i 
	INNER JOIN erp_purch_bil pb ON pb.ers_inventory_id = i.id
	INNER JOIN erp_purch_detail pd ON pd.erp_purch_bil_id = pb.id
	INNER JOIN ers_packageattr p ON p.id = pd.ers_packageAttr_id
	WHERE i.ers_inventory_task_id = itid
	ORDER BY pd.id desc
	;
	-- 获取临时表数量
	SELECT max(id) INTO aCount FROM erp_purch_detail_temp;

	IF ISNULL(aCount) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘亏时不能生成二维码！！';
	END IF;

	-- 初始化动态sql语句
	SET str = '';

	-- 循环编写动态sql语句
	WHILE aCount > 0 DO
		-- 获取临时表数据
		SELECT a.erp_purch_detail_id, a.goodsId, a.ers_packageAttr_id, a.qty, a.degree, pd.erp_purch_bil_id, pb.supplierId
		INTO erp_purch_detail_id, gId, ers_packageAttr_id, qty, degree, pid, aSupplierId
		FROM erp_purch_detail_temp a
		INNER JOIN erp_purch_detail pd ON pd.id = a.erp_purch_detail_id
		INNER JOIN erp_purch_bil pb ON pb.id = pd.erp_purch_bil_id
		WHERE a.id = aCount;
		-- 设置包裹等级
		SET @nLevel = 0;
		WHILE degree > 0 do
			-- 获取包装单品数量
			SELECT a.actualQty INTO actualQty FROM ers_packageAttr a WHERE a.id = ers_packageAttr_id;
			if not(actualQty > 0) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '包装含的单品数量必须大于0！';
			end if;
			-- 生成select 字符串			
			set str = concat(str, ' union all (select ', pid, ' ,', erp_purch_detail_id, ' ,', aSupplierId, ' ,'
				, ers_packageattr_id, ' ,', degree, ' ,', @nLevel, ' ,'
				, actualQty, ' , id', ' ,', gId, ' from t_batchdata limit ', qty, ') ');
			-- 更新包裹等级
			set @nLevel = @nLevel + 1;
			-- 更新包裹深度
			set degree = degree - 1;
			if degree > 0 then
				select a.parentId, qty * a.childCount into ers_packageAttr_id, qty
				from ers_packageAttr a where a.id = ers_packageAttr_id;
			end if;
		END WHILE;

		-- 更新计数器
		SET aCount = aCount - 1;
	END WHILE;

	-- 生成insert语句
	set str = concat('insert into erp_purchDetail_snCode(erp_purch_bil_id, erp_purch_detail_id, supplierId, ers_packageattr_id'
			, ', degree, nLevel, qty, snCode, goodsId)', substr(str, 11));

	-- 执行动态sql语句
	SET @sql1 = str;
	PREPARE stmt1 FROM @sql1;
	EXECUTE stmt1;
	DEALLOCATE PREPARE stmt1 ;
	
	-- 获取临时表数量
	SET aCount = (SELECT max(id) FROM erp_purch_detail_temp);
	-- 循环生成从属关系
	WHILE aCount > 0 DO
		-- 获取对应采购单号
		SELECT pd.erp_purch_bil_id INTO pid
		FROM erp_purch_detail_temp pdt
		INNER JOIN erp_purch_detail pd ON pd.id = pdt.erp_purch_detail_id 
		WHERE pdt.id = aCount;
		-- 暂时没有扫码系统，自动生成包装的从属关系
		UPDATE erp_purchdetail_sncode pds
		SET pds.sSort = concat(pds.id, ',')
		WHERE pds.erp_purch_bil_id = pid AND pds.nLevel = 0;
		-- 更新从属关系
		update erp_purchdetail_sncode a 
		INNER JOIN (
			SELECT a.id, a.ers_packageattr_id, a.erp_purch_detail_id, a.goodsId, a.degree
				, case when isnull(b.id) then null else ceiling(a.snCode/b.childCount) end as pId-- , b.*
			from erp_purchdetail_sncode a left JOIN ers_packageattr b on a.ers_packageattr_id = b.parentId
			INNER JOIN erp_purch_detail pd on a.erp_purch_detail_id = pd.id
			INNER JOIN erp_purch_bil p on p.id = pd.erp_purch_bil_id
			where p.id = pid
		) b on a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId 
				and a.degree - b.degree = 1 and a.snCode = b.pId
		INNER JOIN erp_purchdetail_sncode c on b.id = c.id
			set c.parentId = a.id;

		-- 更新计数器
		SET aCount = aCount - 1;
	END WHILE;

	-- 记录生码时间
	UPDATE ers_inventory_task it SET it.sncodeTime = NOW(), it.lastModifiedId = uId WHERE it.id = itid;
END;;
DELIMITER ;