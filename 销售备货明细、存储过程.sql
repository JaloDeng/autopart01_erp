SET FOREIGN_KEY_CHECKS =0;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	销售备货明细
-- 	--------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS `erp_vendi_bil_stockqty`;
-- CREATE TABLE `erp_vendi_bil_stockqty` (
-- 	`id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `erp_purchDetail_snCode_id` bigint(20) NOT NULL COMMENT '配件二维码ID',
--   `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '销售单主表ID 冗余',
--   `erp_sales_detail_id` bigint(20) NOT NULL COMMENT '销售单明细ID',
--   `goodsId` bigint(20) NOT NULL COMMENT '货品编码',
--   `roomId` bigint(20) DEFAULT NULL COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库',
--   `ers_shelfattr_id` bigint(20) NOT NULL COMMENT '货架编码',
--   `ers_packageattr_id` bigint(20) DEFAULT NULL COMMENT '包裹编码',
--   `packageQty` int(11) DEFAULT '0' COMMENT '数量；--包装数量',
--   `qty` int(11) DEFAULT '0' COMMENT '数量；--最小粒度单位的数量',
--   `stockTime` datetime DEFAULT NULL COMMENT '备货时间',
--   `stockUserId` bigint(20) DEFAULT NULL COMMENT '备货用户ID',
--   `stockEmpId` bigint(20) DEFAULT NULL COMMENT '备货员工ID；--@  erc$staff_id',
--   `stockEmpName` varchar(100) DEFAULT NULL COMMENT '备货员工姓名',
-- 	`stockUserName` varchar(100) DEFAULT NULL COMMENT '备货用户姓名',
--   PRIMARY KEY (`id`),
-- 	KEY `vendi_bil_stockqty_snCode_id1_idx` (`erp_sales_detail_id`,`erp_purchDetail_snCode_id`),
-- 	KEY `vendi_bil_stockqty_snCode_id_idx` (`erp_purchDetail_snCode_id`),
-- 	KEY `vendi_bil_stockqty_vendi_bil_id` (`erp_vendi_bil_id`),
--   KEY `vendi_bil_stockqty_sales_detail_id` (`erp_sales_detail_id`,`ers_shelfattr_id`,`erp_purchDetail_snCode_id`),
--   KEY `vendi_bil_stockqty_goodsId` (`goodsId`,`erp_sales_detail_id`,`ers_shelfattr_id`),
--   KEY `vendi_bil_stockqty_goodsId1_idx` (`goodsId`,`ers_shelfattr_id`),
--   KEY `vendi_bil_stockqty_ers_packageattr_id_idx` (`ers_packageattr_id`),
--   KEY `vendi_bil_stockqty_ers_shelfattr_id` (`ers_shelfattr_id`,`ers_packageattr_id`,`erp_sales_detail_id`) USING BTREE,
--   CONSTRAINT `fk_vendi_bil_stockqty_sales_detail_id` FOREIGN KEY (`erp_sales_detail_id`) 
-- 		REFERENCES `erp_sales_detail` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
--   CONSTRAINT `fk_vendi_bil_stockqty_ers_shelfattr_id` FOREIGN KEY (`ers_shelfattr_id`) 
-- 		REFERENCES `ers_shelfattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
--   CONSTRAINT `fk_vendi_bil_stockqty_goodsId` FOREIGN KEY (`goodsId`) 
-- 		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='备货单数量明细'
-- ;

-- *****************************************************************************************************
-- 创建存储过程 p_vendi_stock_shelfattr, 销售出仓备货
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_vendi_stock_shelfattr;
DELIMITER ;;
CREATE PROCEDURE p_vendi_stock_shelfattr(
	aid bigint(20) -- 货物二维码ID erp_purchDetail_snCode.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, sdId BIGINT(20) -- 销售单明细ID erp_sales_detail.id
)
BEGIN

	DECLARE aEmpId, aGoodsId, aErs_packageattr_id, aShelfId, aRoomId, aShelfBookId BIGINT(20);
	DECLARE vId, sdErs_packageAttr_id BIGINT(20);
	DECLARE aState, aStockState, vCheck TINYINT;
	DECLARE aDegree, aQty, sdDegree, sdPackageQty, sdQty, haveOutQty INT;
	DECLARE aEmpName, aUserName VARCHAR(100);
	DECLARE msg, aSort VARCHAR(1000);
	DECLARE sdSTime, sdOTime datetime;

	-- 判断用户是否合理
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) OR uId = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户！';
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	END IF;

	-- 获取二维码的相关信息
	select a.goodsId, a.ers_packageattr_id, a.qty, a.ers_shelfattr_id, s.roomId, a.ers_shelfbook_id
		, a.degree, a.state, a.stockState, a.sSort 
	into aGoodsId, aErs_packageattr_id, aQty, aShelfId, aRoomId, aShelfBookId
		, aDegree, aState, aStockState, aSort
	from erp_purchDetail_snCode a INNER JOIN ers_shelfattr s on s.id = a.ers_shelfattr_id
	where a.id = aid;

	-- 根据二维码状态判断是否可以备货
	if isnull(aGoodsId) then
		set msg = concat('指定的配件二维码（编号：', aid,'）或对应仓库不存在，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif aState <> 1 THEN
		set msg = concat('指定的配件（编号：', aGoodsId,'）二维码（编号：', aid,'）尚未进仓或已经出仓，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aStockState <> 0 THEN
		set msg = concat('指定的配件（编号：', aGoodsId,'）二维码（编号：', aid,'）已经备货，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aShelfBookId < 0 THEN
		set msg = concat('指定的配件（编号：', aGoodsId,'）二维码（编号：', aid,'）已被拆包，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 判断二维码或低级包装中二维码是否处于核销状态
	IF EXISTS(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_goods_cancel_detail c 
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId
			and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort AND c.erp_purchDetail_snCode_id = a.id LIMIT 1) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装处于核销状态或已核销出仓，不能进行整体销售出仓！';
	END IF;

	-- 获取销售明细相关信息
	SELECT v.id, sd.ers_packageAttr_id, sd.packageQty, sd.qty, p.degree, v.isCheck, sd.stockTime, sd.outTime
	INTO vId, sdErs_packageAttr_id, sdPackageQty, sdQty, sdDegree, vCheck, sdSTime, sdOTime
	FROM erp_vendi_bil v 
	INNER JOIN erp_sales_detail sd ON sd.erp_vendi_bil_id = v.id
	INNER JOIN ers_packageattr p ON p.id = sd.ers_packageAttr_id
	WHERE sd.id = sdId AND sd.goodsId = aGoodsId;
	-- 根据销售单状态判断是否可以备货
	if isnull(vId) THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）不存在或者配件与指定的二维码（编号：'
			, aid,'）对应的配件（编号：', aGoodsId,'）不匹配，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF sdSTime > 0 THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）对应的销售单（编号：', vId,'）已完成备货，不能再次备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF sdOTime > 0 THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）对应的销售单（编号：', vId,'）已完成出仓，不能再次备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif aDegree > sdDegree THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）配件包装级别（', sdDegree, '）低于指定的二维码（编号：'
			, aid,'）配件包装级别（', aDegree,'），不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif vCheck <> 1 THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）对应的销售单（编号：', vId,'）没有审核通过，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	if exists(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.state = -1
		and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装存在已经出仓的记录，不能进行整体备货';
	ELSEIF EXISTS(select 1 from erp_purchDetail_snCode a, erp_purchDetail_snCode b
		where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId and a.stockState = 1
		and b.id = aid and left(a.sSort, CHAR_LENGTH(b.sSort)) = b.sSort limit 1) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该配件包装存在已经备货的记录，不能进行整体备货';
	end if;

	-- 判断该销售明细已经备货的单品数量 + 指定二维码的单品数量 是否超出 该销售明细实际需要备货的单品数量
	set haveOutQty = ifnull((select sum(a.qty) from erp_vendi_bil_stockqty a 
			where a.erp_sales_detail_id = sdId and a.goodsId = aGoodsId
		), 0);

	if sdQty = haveOutQty THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）配件（编号：'
			, aGoodsId,'）销售单品数量（', sdQty,'）已经全部备货，不能再次备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif aQty + haveOutQty > sdQty THEN
		set msg = concat('指定的销售单明细（编号：', sdId,'）配件（编号：', aGoodsId,'）销售单品数量（', sdQty,'）小于指定的二维码（编号：'
			, aid,'）配件包装单品数量（', aQty,'）与已经备货的单品数量（', haveOutQty,'）之和，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 写入备货单明细
	set msg = concat('配件（编号：', aGoodsId,'）二维码（编号', aid,'）库房（编号', aRoomId
		,'）仓位（编号：', aShelfId,'）备货时，');
	insert into erp_vendi_bil_stockqty(erp_purchdetail_sncode_id, erp_vendi_bil_id, erp_sales_detail_id
			, goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty
			, stockTime, stockUserId, stockEmpId, stockEmpName)
		select aid, vId, sdId
			, aGoodsId, aErs_packageattr_id, aRoomId, aShelfId, 1, aQty
			, now(), uId, aEmpId, aEmpName
		;
		if ROW_COUNT() <> 1 then
			set msg = concat(msg, '未能同步新增备货单明细！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

	-- 修改二维码的备货标志为1（备货）
	update erp_purchDetail_snCode a , erp_purchDetail_snCode b 
	set a.stockState = 1
	where a.erp_purch_detail_id = b.erp_purch_detail_id and a.goodsId = b.goodsId AND a.stockState = 0
			and b.id = aid and b.sSort = left(a.sSort, CHAR_LENGTH(b.sSort))
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat(msg, '未能成功写入二维码备货标志！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 再次获取销售明细已备货数量
	set haveOutQty = ifnull((select sum(a.qty) from erp_vendi_bil_stockqty a 
			where a.erp_sales_detail_id = sdId and a.goodsId = aGoodsId
		), 0);

	-- 判断该二维码对应的销售明细数量是否全部备货
	IF sdQty = haveOutQty THEN

		-- 修改销售明细表的备货时间
		UPDATE erp_sales_detail s SET s.stockTime = NOW(), s.lastModifiedId = uId
		WHERE s.id = sdId;
		if ROW_COUNT() <> 1 THEN
			set msg = concat(msg, '备货完毕，未能成功修改销售明细备货时间！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

    -- 判断该二维码对应的销售主表数量是否全部备货
		IF NOT EXISTS(
			SELECT 1 FROM erp_sales_detail s,	
				(SELECT a.id, IFNULL(SUM(c.qty), 0) AS sQty FROM erp_sales_detail a
					INNER JOIN erp_sales_detail b ON b.erp_vendi_bil_id = a.erp_vendi_bil_id
					LEFT JOIN erp_vendi_bil_stockqty c ON c.erp_sales_detail_id = a.id 
					WHERE b.id = sdId GROUP BY a.id
				) b WHERE b.id = s.id AND s.qty > b.sQty LIMIT 1
		) THEN

			-- 修改销售订单主表的备货时间
			update erp_vendi_bil a 
				set a.stockTime = NOW(), a.stockUserId = uId, a.stockEmpId = aEmpId, a.stockEmpName = aEmpName
				, a.lastModifiedId = uId, a.lastModifiedEmpId = aEmpId, a.lastModifiedEmpName = aEmpName, a.lastModifiedBy = aUserName
			where a.id = vId;
			if ROW_COUNT() <> 1 THEN
					set msg = concat(msg, '备货完毕，未能成功修改销售主表备货时间、备货人！');
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;

		END IF;
	END IF;

END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_vendi_stock_shelf, 销售备货
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_call_vendi_stock_shelf;
DELIMITER ;;
CREATE PROCEDURE `p_call_vendi_stock_shelf`(
	aids VARCHAR(65535) CHARSET latin1 -- 货物二维码ID erp_purchDetail_snCode.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, sdId BIGINT(20) -- 销售单明细ID erp_sales_detail.id
	, qty INT(11) -- 二维码个数
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
		CALL p_vendi_stock_shelfattr(ExtractValue(aids, '//a[$i]'), uId, sdId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;