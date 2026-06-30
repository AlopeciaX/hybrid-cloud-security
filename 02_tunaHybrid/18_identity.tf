resource "azurerm_user_assigned_identity" "vmss_kv_identity" {
  name = "tuna-vmss-kv-identity"
  resource_group_name = var.rgname
  location            = var.loca1

  depends_on = [
    azurerm_resource_group.tuna_rg
  ]
}

# 참고: 이전에 여기에 azurerm_role_assignment(Reader, Storage Blob Data
# Contributor)를 추가했었으나, 이 구독 계정이 Microsoft.Authorization/
# roleAssignments/write 권한 자체가 없어서(AuthorizationFailed 확인됨)
# terraform apply 시 실패함. RBAC 역할 할당을 전부 제거하고:
#  - MySQL FQDN은 az 조회 없이 고정 패턴으로 직접 구성 (Reader 불필요)
#  - Storage Account 키는 00_bootstrap.sh가 Key Vault 시크릿으로 저장해두고,
#    각 스크립트가 그 시크릿을 읽어서 --account-key로 사용 (RBAC 불필요)
# 으로 대체함.