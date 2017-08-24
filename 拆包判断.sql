select DISTINCT a.id, a.ers_packageattr_id, a.ers_shelfattr_id, a.qty
			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
			where a.id = b.parentId 
			and c.id = 318 and b.nLevel <= c.nLevel
			and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
;

SELECT * FROM ers_shelfbook a INNER JOIN (
			select DISTINCT a.id, a.ers_packageattr_id, a.ers_shelfattr_id, a.qty
			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
			where a.id = b.parentId 
			and c.id = 318 and b.nLevel <= c.nLevel
			and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
		) b on b.ers_packageattr_id = a.ers_packageattr_id and b.ers_shelfattr_id = a.ers_shelfattr_id
;

SELECT a.id AS aud, a.goodsId, a.ers_packageattr_id AS aPackId, a.degree, a.roomId
			, a.ers_shelfattr_id AS aShelfId, a.packageQty, a.qty AS aQty, a.verlock 
			, b.id AS bid, b.ers_packageattr_id AS bPackId, b.ers_shelfattr_id AS bShelfId, b.qty AS bQty
			FROM ers_shelfbook a INNER JOIN (
			select DISTINCT a.id, a.ers_packageattr_id, a.ers_shelfattr_id, a.qty
			from erp_purchDetail_snCode a, erp_purchDetail_snCode b, erp_purchDetail_snCode c
			where a.id = b.parentId 
			and c.id = 318 and b.nLevel <= c.nLevel
			and locate(a.sSort, c.sSort) > 0 and locate(b.sSort, c.sSort) = 0
		) b on b.ers_packageattr_id = a.ers_packageattr_id and b.ers_shelfattr_id = a.ers_shelfattr_id
WHERE a.qty > 0
;