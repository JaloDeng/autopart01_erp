DROP PROCEDURE IF EXISTS p_suppliersGoods_setExchangeCode;
DELIMITER ;;
CREATE PROCEDURE `p_suppliersGoods_setExchangeCode` (
	gid	bigint(20)	-- 商品ID
	, sid	bigint(20)	-- 供应商ID
	, eCode VARCHAR(255)	-- 商品互换码
)
BEGIN
	IF eCode <> '' THEN 
		IF EXISTS(SELECT 1 FROM erp_suppliersgoods a WHERE a.goodsId = gid AND a.crm_suppliers_id = sid) THEN
			UPDATE erp_suppliersgoods a SET a.exchangeCode = eCode WHERE a.goodsId = gid AND a.crm_suppliers_id = sid;
			SELECT 1 AS ok;
		ELSE
			IF EXISTS(SELECT 1 FROM ers_packageattr a WHERE a.goodsId = gid) THEN
				INSERT INTO erp_suppliersgoods (crm_suppliers_id, ers_packageAttr_id, goodsId, exchangeCode) 
				SELECT sid, a.id, gid, eCode 
				FROM ers_packageattr a 
				WHERE a.goodsId = gid LIMIT 1;
				SELECT 1 AS ok;
			ELSE
				SELECT 0 AS ok;
			END IF;
		END IF;
	END IF;
END;;
DELIMITER ;