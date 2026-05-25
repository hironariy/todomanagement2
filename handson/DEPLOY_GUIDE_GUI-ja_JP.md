# Todo Management GUI デプロイガイド

[English](DEPLOY_GUIDE_GUI.md) | [简体中文](DEPLOY_GUIDE_GUI-zh_CN.md) | [日本語](DEPLOY_GUIDE_GUI-ja_JP.md)

このガイドは、初心者向けの Azure Portal ベース (GUI ファースト) でのデプロイ手順を説明します。ワークショップまたははじめてのデプロイに使用してください。

所要時間の目安: 45 分から 60 分。

---

## 用語統一標準 (EN/JA/ZH)

3 言語版で次の用語を統一して使用します:

- Microsoft Entra ID
- Repository variables
- Azure Container Apps Environment

補足:

- このガイドでの `AZURE_CLIENT_ID` は Microsoft Entra ID アプリケーションのクライアント ID を指します。
- このガイドでの `AZURE_TENANT_ID` は Microsoft Entra ID のテナント ID を指します。

---

## ワークフロー概要

このガイドは以下のフェーズに従います:

1. **フェーズ 1: Azure インフラストラクチャセットアップ** (Portal 経由) - まずすべての必要な Azure リソースを作成します
2. **フェーズ 2: リポジトリセットアップ** - テンプレートからリポジトリを作成します
3. **フェーズ 3: GitHub Actions 構成** - CI/CD を構成し、ワークフローを有効にしてデプロイします
4. **フェーズ 4: 検証** - デプロイされたアプリケーションをテストします

IaC/Bicep パスについては、`DEPLOY_GUIDE.md` (上級トラック) を参照してください。

---

## 前提条件

- Azure サブスクリプション権限: `Owner`、または `Contributor` と `User Access Administrator`
- Microsoft Entra ID でアプリ登録を作成するための権限:
  - `Application Administrator`、`Cloud Application Administrator`、または `Application Developer` ロール
  - 組織がすべてのユーザーにアプリ登録を許可している場合 (デフォルト設定)、特別なロールは不要です
  - 参考: [Least privileged roles by task - Microsoft Entra ID (MS Learn)](https://learn.microsoft.com/entra/identity/role-based-access-control/delegate-by-task)
- GitHub アカウント
- このテンプレートからリポジトリを作成する権限

ワークショップ参加者向けの重要な注意事項:

- テンプレートからリポジトリを作成する場合、このワークショップフローでは `Public` の表示設定を使用してください
- `Private` リポジトリには、このビギナーガイドの範囲外の追加 GitHub 認証と CI/CD 設定が必要です
- 事前に名前、リージョン、必要な ID を準備しておいてください
- リポジトリを作成する前に Azure インフラストラクチャを作成してください。こうすることで GitHub Actions に必要な値がすでに揃っています

---

## フェーズ 1: Azure Portal からインフラストラクチャを作成

> 所要時間の目安: 30-40 分

まずすべての Azure リソースを作成します。後で GitHub Actions を構成するために、リソース ID と構成詳細が必要になります。

> 注意: Portal の表示言語が日本語または中国語の場合、英語名で検索しても一部サービスが見つからないことがあります。その場合は表示言語のサービス名で検索してください。
> 例: `Resource groups` / `リソース グループ` / `资源组`、`Virtual networks` / `仮想ネットワーク` / `虚拟网络`、`Container Apps` / `コンテナー アプリ` / `容器应用`

### アーキテクチャ概要

次の図は、すべてのコンポーネントが Azure 環境にどのようにデプロイされるかを示しています:

![アーキテクチャ概要 - Azure 上の Todo Management アプリケーション](../images/01.Architecture.png)

**アーキテクチャの特徴:**

- ユーザーは Container Apps を通じて Web アプリケーションにアクセスします
- Web と API コンテナーは、Virtual Network 内の同じ Container Apps Environment で実行されます
- API は管理対象アイデンティティを使用して PostgreSQL データベースに安全にアクセスします
- Container Registry がコンテナーイメージを保存します
- すべてのネットワークトラフィックは Virtual Network 内のサブネットを通じて流れます
- Microsoft Entra ID がユーザー認証を処理します

---

### リソース作成順序

適切なネットワーク構成を確保するために、このシーケンスでリソースを作成してください:

1. Resource Group
2. Virtual Network とサブネット
3. Azure Container Registry (ACR) とプライベートエンドポイント
4. Azure Container Apps Environment
5. Azure Database for PostgreSQL Flexible Server
6. ユーザー割り当て管理対象アイデンティティ (API 用)
7. Microsoft Entra ID アプリ登録 (Web サインイン用)

---

### ステップ 1.1: Resource Group を作成

参考: [Resource Group を作成する - Azure Portal (MS Learn)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#create-resource-groups)

1. Azure Portal で **Home** > **Resource groups** に移動します
2. **Create** をクリックします
3. **Create a resource group** ページで:
   - **Subscription**: サブスクリプションを選択します
   - **Resource group**: 名前を入力します (例: `rg-todomanagement-dev`)
   - **Region**: リージョンを選択します (例: `Japan East`)
4. **Review + Create** -> **Create** をクリックします
5. デプロイが完了するまで待ちます (通常 1-3 秒)

> 次: 後のステップ用に Resource Group 名をメモしておいてください

---

### ステップ 1.2: Virtual Network とサブネットを作成

参考: [Virtual Network を作成する - Azure Portal (MS Learn)](https://learn.microsoft.com/en-us/azure/virtual-network/quick-create-portal)

Virtual Network はリソースのための分離されたネットワーク空間を提供します。異なるワークロードタイプ向けに複数のサブネットを作成します。

1. Azure Portal で **Home** > **Virtual networks** を検索して移動します
2. **Create** をクリックします
3. **Create virtual network** ページで:

   - **Subscription**: サブスクリプションを選択します
   - **Resource group**: ステップ 1.1 からの Resource Group を選択します
   - **Name**: 名前を入力します (例: `vnet-todomanagement-dev`)
   - **Region**: Resource Group と同じリージョン (例: `Japan East`)
4. **Next** をクリックします
5. **Security** 設定をスキップするため **Next** をクリックします
6. アドレス空間を構成します
   1. **IPv4 address space** で以下を設定します:
      - **Address space**: `10.0.0.0/16` (65,536 個の IP アドレスを提供)

   2. サブネットを作成します

**Add a subnet** をクリックして、3 つのサブネットを作成します:

#### サブネット 1: Container Apps サブネット

- **Name**: `snet-container-apps`
- **Subnet address range**: `10.0.1.0/24` (256 アドレス)
- **Subnet Delegation**: `Microsoft.App/environments`
- **Other settings**: デフォルトのままにします
- **Add** をクリックします

![Container App Environment 用サブネットを作成](image/DEPLOY_GUIDE_GUI/1776058038608.png)

#### サブネット 2: プライベートエンドポイントサブネット

- **Name**: `snet-private-endpoints`
- **Subnet address range**: `10.0.2.0/24` (256 アドレス)
- デフォルトのままにします
- **Add** をクリックします

![プライベートエンドポイント用サブネットを作成](image/DEPLOY_GUIDE_GUI/1776060483160.png)

#### サブネット 3: PostgreSQL サブネット

- **Name**: `snet-postgresql`
- **Subnet address range**: `10.0.3.0/24` (256 アドレス)
- **Subnet Delegation**: `Microsoft.DBforPostgreSQL/flexibleServers`
- **Other settings**: デフォルトのままにします
- **Add** をクリックします

![PostgreSQL 用サブネットを作成](image/DEPLOY_GUIDE_GUI/1776060713048.png)
7. 3 つのサブネットすべてを追加したら、**Review + create** -> **Create** をクリックします
8. Virtual Network デプロイメントが完了するまで待ちます (通常 5-10 秒)

次: VNet 名とサブネット名をメモしておいてください
> **リソース作成時にサブネットを参照してください:**
> - Container Apps Environment → `snet-container-apps`
> - プライベートエンドポイント (ACR、PostgreSQL オプション) → `snet-private-endpoints`
> - PostgreSQL Flexible Server → `snet-postgresql`

---

### ステップ 1.3: Azure Container Registry (ACR) を作成

参考: [コンテナーレジストリを作成する - Azure Portal (MS Learn)](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal)

1. Azure Portal で **Home** > **Container registries** を検索して移動します
2. **Create** をクリックします
3. **Create container registry** ページで:

   - **Subscription**: サブスクリプションを選択します
   - **Resource group**: ステップ 1.1 からの Resource Group を選択します
   - **Registry name**: 一意の名前を入力します (例: `mytodoappacr`)
     - 小文字と数字のみを使用する必要があります
     - `<your-acr-name>.azurecr.io` として使用されます
   - **Location**: Resource Group と同じ場所 (例: `Japan East`)
   - **Pricing plan**: `Premium` を選択します (プライベートエンドポイントで ACR にアクセスするため)
   - その他の設定をデフォルトのままにします
4. **Next: Networking** をクリックします (プライベートエンドポイントを構成するため)
5. **Networking** ページで:

   - **Connectivity**: `Private endpoint` を選択します
   - **Add** をクリックしてプライベートエンドポイントを作成します
   - プライベートエンドポイント作成ダイアログで:
     - **Name**: `pe-acr`
     - **Subnet**: ステップ 1.2 から `snet-private-endpoints` を選択します
     - **Integrate with private DNS zone**: `Yes`
     - **OK** をクリックします
       ![ACR 用プライベートエンドポイントを作成](image/DEPLOY_GUIDE_GUI/1776061342465.png)
6. プライベートエンドポイントが構成されたら、**Review + Create** -> **Create** をクリックします
7. ACR デプロイメントが完了するまで待ちます (通常 3-5 分)

公開アクセスが無効なため、ACR Tasks はイメージを構築するために到達可能なパスが必要です。次のオプションのいずれかを選択してください:

- **オプション A:** `AzureContainerRegistry.<region>` サービスタグの特定公開アクセスを許可します
- **オプション B:** お使いのリージョンが ACR エージェントプールをサポートしている場合、VNet 内にエージェントプールを作成します

#### オプション A: 特定公開アクセスを有効にする

1. **Go to resource** をクリックして ACR リソースを開きます
2. **Networking** をクリックします

- **Public network access**: **Selected networks** を選択します
- **Address range**: `AzureContainerRegistry.<region>` の IP アドレス範囲を追加します (例: `AzureContainerRegistry.JapanEast`)
  最新の [Azure IP Ranges and Service Tags - Public Cloud](https://www.microsoft.com/en-us/download/details.aspx?id=56519) ファイルをダウンロードできます。

  ![AzureContainerRegistry.JapanEast の IP 範囲](image/DEPLOY_GUIDE_GUI/1776145113506.png)
- **Save** をクリックします

  ![ACR のネットワーク設定を保存](image/DEPLOY_GUIDE_GUI/1776145300884.png)

#### オプション B: VNet にエージェントプールを作成

参考: [ACR Tasks でエージェントプールを作成および管理する](https://learn.microsoft.com/en-us/azure/container-registry/tasks-agent-pools)

1. Azure Cloud Shell を開いて次のコマンドを実行します

   > Cloud Shell の環境は必ず **PowerShell** を選択してください (このガイドのコマンドは PowerShell 形式です)。

   ```powershell
   # ステップ 1.1 から Resource Group 名に置き換えます
   $resourceGroupName = "rg-todomanagement-dev"
   # ステップ 1.2 から Virtual Network 名に置き換えます
   $vNetName = "vnet-todomanagement-dev"
   $subnetName = "snet-private-endpoints"
   # Azure Container Registry 名に置き換えます
   $registryName = "mytodoappacr01"
   $agentPoolName = "myagentpool"
   # サブネット ID を取得します
   $subnetId=$(az network vnet subnet show --resource-group $resourceGroupName --vnet-name $vNetName --name $subnetName --query id --output tsv)
   az acr agentpool create --registry $registryName --name $agentPoolName --tier S1 --subnet-id $subnetId
   ```

**次: ACR 名をメモしておいてください (`.azurecr.io` なし)**

---

### ステップ 1.4: Azure Container Apps Environment とプレースホルダーコンテナーアプリを作成

参考: [Container Apps で最初のコンテナーアプリを作成する - Azure Portal (MS Learn)](https://learn.microsoft.com/en-us/azure/container-apps/quickstart-portal)

まず API Container App を作成します。このステップで Container Apps Environment も作成されます。

> 推奨: Container App 名は `app-todomanagement-api` と `app-todomanagement-web` をそのまま使用してください。別名にすると、後続の Microsoft Entra ID アプリ登録のリダイレクト URL 修正と GitHub Repository variables 修正が必要になります。

1. Azure Portal で **Home** > **Container Apps** を検索して移動します
2. **Create** > **Container App** をクリックします
   ![1776062129864](image/DEPLOY_GUIDE_GUI/1776062129864.png)
3. **Basics** ページで:

   - **Project details**:
     - **Subscription**: サブスクリプションを選択します
     - **Resource group**: ステップ 1.1 からの Resource Group を選択します
     - **Container app name**: 「`app-todomanagement-api`」を入力します
     - その他の設定をデフォルトのままにします
       ![Container App プロジェクト詳細をセットアップ](image/DEPLOY_GUIDE_GUI/1776062438077.png)
   - **Container Apps environment**:
     - **Region**: Resource Group と同じリージョン
     - **Container Apps environment** として、**Create new environment** をクリックします
       **Create Container Apps environment** ダイアログで:
       1. **Basics** ページで:

          - **Environment name**: 名前を入力します (例: `cae-todomanagement-dev`)
          - その他の設定をデフォルトのままにします
       2. **Monitoring** ページで:

          - **Logs Destination**: **Azure Log Analytics** を選択します
          - **Log Analytics workspace**: **Create new** をクリックします
            - **Name**: 名前を入力します (例: `law-todomanagement-dev`)
            - **OK** をクリックします

          ![Container App 用 Log Analytics ワークスペースを作成](image/DEPLOY_GUIDE_GUI/1776063748691.png)
       3. **Networking** ページで:

          - **Public Network Access**: **Enabled** を選択します。このあとのステップでアプリケーションを検証するためです
          - **Use your own virtual network**: `Yes` を選択してから、ステップ 1.2 から virtual network とサブネットを指定します
          - その他の設定をデフォルトのままにします

          ![Container App のネットワークをセットアップ](image/DEPLOY_GUIDE_GUI/1776064059196.png)
       4. **Create** をクリックします

          ![Container App の基本をセットアップ](image/DEPLOY_GUIDE_GUI/1776064144478.png)
4. **Next: Container** をクリックします
5. **Container** ページで:

   - **Name**: 「`app-todomanagement-api`」を入力します
   - **Image source**: 「`Docker Hub or other registries`」を選択します
   - **Image type**: 「`Public`」を選択します
   - **Registry login server**: 「`mcr.microsoft.com`」を入力します
   - **Image and tag**: 「`k8se/quickstart:latest`」を入力します
   - その他の設定をデフォルトのままにします

![コンテナー設定を指定](image/DEPLOY_GUIDE_GUI/1776150061884.png)

> 注: このステップでは、プレースホルダーコンテナーアプリを作成しています。実際のイメージは、後で GitHub Actions を通じてデプロイされます。

6. **Next: Ingress** をクリックします
7. **Ingress** ページで:
   - **Ingress**: 有効になっていることを確認します
   - **Target port**: 「`80`」を入力します
   - その他の設定をデフォルトのままにします
     ![イングレス設定を構成](image/DEPLOY_GUIDE_GUI/1776150314554.png)
8. **Review + Create** -> **Create** をクリックします
9. デプロイメントが完了するまで待ちます (通常 4-5 分)
10. デプロイメントが完了したら、**Go to resource** をクリックして、作成されたアプリに移動します
11. **Overview** ページで、API アプリの **Application URL** をメモします (例: `https://app-todomanagement-api.internal.politebay-d0fe95ab.japaneast.azurecontainerapps.io`)

次: Container Apps Environment 名と API アプリの Application URL をメモしておいてください

Web Container App を作成するために同じステップを繰り返します。

1. Azure Portal で **Home** > **Container Apps** を検索して移動します
2. **Create** > **Container App** をクリックします
   ![1776062129864](image/DEPLOY_GUIDE_GUI/1776062129864.png)
3. **Basics** ページで:

   - **Project details**:
     - **Subscription**: サブスクリプションを選択します
     - **Resource group**: ステップ 1.1 からの Resource Group を選択します
     - **Container app name**: 「`app-todomanagement-web`」を入力します
     - その他の設定をデフォルトのままにします
   - **Container Apps environment**:
     - **Region**: Resource Group と同じリージョン (例: `Japan East`)
     - **Container Apps environment**: 前のステップで作成した Container Apps Environment を選択します (例: `cae-todomanagement-dev`)
       ![Web Container App の基本をセットアップ](image/DEPLOY_GUIDE_GUI/1776065673120.png)
4. **Next: Container** をクリックします
5. **Container** ページで:

   - **Name**: 「`app-todomanagement-web`」を入力します
   - **Image source**: 「`Docker Hub or other registries`」を選択します
   - **Image type**: 「`Public`」を選択します
   - **Registry login server**: 「`mcr.microsoft.com`」を入力します
   - **Image and tag**: 「`k8se/quickstart:latest`」を入力します
   - **CPU and memory**: 「`0.25 CPU cores, 0.5 Gi memory`」を選択します
   - その他の設定をデフォルトのままにします

   > 注: このステップでは、プレースホルダーコンテナーアプリを作成しています。実際のイメージは、後で GitHub Actions を通じてデプロイされます。
   >
6. **Next: Ingress** をクリックします
7. **Ingress** ページで:

   - **Ingress**: 有効になっていることを確認します
   - **Ingress traffic**: 「`Accepting traffic from anywhere`」を選択します
   - **Target port**: 「`80`」を入力します
   - その他の設定をデフォルトのままにします
     ![イングレス設定を構成](image/DEPLOY_GUIDE_GUI/1776150754561.png)
8. **Review + Create** -> **Create** をクリックします
9. デプロイメントが完了するまで待ちます (通常 1-2 分)
10. デプロイメントが完了したら、**Go to resource** をクリックして、作成されたアプリに移動します
11. **Overview** ページで、Web アプリの **Application URL** をメモします (例: `https://app-todomanagement-web.politebay-d0fe95ab.japaneast.azurecontainerapps.io`)

次: Web Application URL をステップ 1.8 とステップ 3.3 用に保持しておいてください

---

### ステップ 1.5: Azure Database for PostgreSQL Flexible Server を作成

参考: [サーバーを作成する - Azure Database for PostgreSQL Flexible Server (MS Learn)](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/quickstart-create-server-portal)

1. Azure Portal で **Home** > **Azure Database for PostgreSQL flexible servers** を検索して移動します
2. **Create** をクリックします
3. **Create Azure Database for PostgreSQL Flexible Server** ページで:
   - **Subscription**: サブスクリプションを選択します
   - **Resource group**: ステップ 1.1 からの Resource Group を選択します
   - **Server name**: 名前を入力します (例: `pg-todomanagement-dev`)
   - **Region**: Resource Group と同じリージョン
   - **PostgreSQL version**: 「`17`」を選択します
   - **Workload type**: 「`Development`」を選択します
   - **Compute + storage**: 開発用にデフォルトのままにします
   - **Authentication method**: 「`Microsoft Entra authentication only`」を選択します
   - **Microsoft Entra administrator**: ご使用のユーザーを選択します。
     ![PostgreSQL の基本をセットアップ](image/DEPLOY_GUIDE_GUI/1776066601112.png)
4. **Next: Networking** をクリックします
5. **Networking** ページで:
   - **Connectivity method**: 「`Private access (VNet Integration)`」を選択します (セキュリティ上推奨されます)
   - **Virtual network**:
     - **Subscription**: サブスクリプションを選択します
     - **Virtual network**: ステップ 1.2 から VNet を選択します (例: `vnet-todomanagement-dev`)
     - **Subnet**: 「`snet-postgresql`」を選択します (ステップ 1.2)
   - **Private DNS integration**:
     - **Subscription**: サブスクリプションを選択します
     - **Private DNS zone**: 「`(New) privatelink.postgres.database.azure.com`」を選択します。同じ名前のプライベートゾーンが既に存在する場合、Azure は「`(New) pg-todomanagement-dev.private.postgres.database.azure.com`」などのゾーンを表示する場合があります。
       ![1776067049715](image/DEPLOY_GUIDE_GUI/1776067049715.png)
6. **Review + Create** -> **Create** をクリックします
7. デプロイメントが完了するまで待ちます (通常 5-10 分)

**次: 以下をメモしておいてください:**

- PostgreSQL サーバーエンドポイント (例: `pg-todomanagement-dev.postgres.database.azure.com`)

---

### ステップ 1.6: ユーザー割り当て管理対象アイデンティティを作成

参考: [ユーザー割り当て管理対象アイデンティティを作成する - Azure Portal (MS Learn)](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?tabs=azure-portal)

このアイデンティティは、API コンテナーが PostgreSQL にアクセスするために使用されます。

1. Azure Portal で **Home** > **Managed Identities** を検索して移動します
2. **Create** をクリックします
3. **Create User Assigned Managed Identity** ページで:
   - **Subscription**: サブスクリプションを選択します
   - **Resource group**: ステップ 1.1 からの Resource Group を選択します
   - **Region**: Resource Group と同じリージョン
   - **Name**: 名前を入力します (例: `uai-todomanagement-api`)
     ![ユーザー割り当てアイデンティティを作成](image/DEPLOY_GUIDE_GUI/1776067573014.png)
4. **Review + Create** -> **Create** をクリックします
5. デプロイメントが完了するまで待ちます (通常 1-5 秒)
6. 新しく作成された管理対象アイデンティティをクリックして開きます

**次: 以下をメモしておいてください:**  

   - **Client ID** (Overview の下)
   - **Resource ID** (Properties の下)

---

### ステップ 1.7: PostgreSQL データベースとパーミッションを構成

参考: [サーバーパラメーターを構成する - Azure Database for PostgreSQL (MS Learn)](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-server-parameters)

1. Azure Portal で PostgreSQL サーバー (ステップ 1.5) に移動します
2. 左のメニューで **Databases** をクリックします
3. **Add** をクリックします
4. データベース名を入力: `tododb`
5. **Save** をクリックします
6. データベース作成が完了するまで待ちます (通常 1-2 分)

**PostgreSQL データベースに管理対象アイデンティティアクセスを許可:**

1. Azure Portal で PostgreSQL サーバーに移動します
2. 左のメニューで **Security** -> **Authentication** をクリックします
3. **Add Microsoft Entra administrators** をクリックします。**Select Microsoft Entra administrators** ダイアログで、前のステップで作成した管理対象アイデンティティを検索します (例: `uai-todomanagement-api`)、**Select** をクリックします
   ![1776068408432](image/DEPLOY_GUIDE_GUI/1776068408432.png)
4. **Save** をクリックして、構成が適用されるまで待ちます

> 注: 最小限の権限を持つデータベースロール設計はこのハンズオンガイドの範囲外です。Microsoft Entra プリンシパルに対するデータベースユーザーとロール付与の作成に関する本番環境ガイダンスについては、[Manage Microsoft Entra Users - Azure Database for PostgreSQL | Microsoft Learn](https://learn.microsoft.com/en-us/azure/postgresql/security/security-manage-entra-users) を参照してください。

---

### ステップ 1.8: Microsoft Entra ID アプリ登録を作成

参考: [アプリケーションを登録する - Microsoft Entra ID (MS Learn)](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)

このアプリ登録により、Web ユーザーが Microsoft Entra ID アカウントでサインインできるようになります。

1. Azure Portal で **Microsoft Entra ID** を開きます (または検索します)
2. 左のメニューで **App registrations** をクリックします
3. **New registration** をクリックします
4. **Register an application** ページで:
   - **Name**: 名前を入力します (例: `todo-web-app`)
   - **Supported account types**: **Accounts in this organizational directory only** を選択します
   - **Redirect URI**: **Single-page application (SPA)** を選択して、ステップ 1.4 で作成した Web Container App の **Application URL** を入力します (例: `https://app-todomanagement-web.politebay-d0fe95ab.japaneast.azurecontainerapps.io`)
5. **Register** をクリックします
   ![Web 認証用アプリを登録](image/DEPLOY_GUIDE_GUI/1776071479250.png)
6. アプリが登録されました。以下をメモしておいてください:
   - **Application (client) ID** (Overview ページ)
   - **Directory (tenant) ID** (Overview ページ)

---

### ステップ 1.9: サマリー - すべてのリソース詳細を収集

フェーズ 2 に進む前に、Azure リソースから以下のすべての情報を収集してください:

- **Subscription ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Resource Group**: `rg-todomanagement-dev`
- **Virtual Network**: `vnet-todomanagement-dev`
- **Container Apps Subnet**: `snet-container-apps`
- **Private Endpoints Subnet**: `snet-private-endpoints`
- **PostgreSQL Subnet**: `snet-postgresql`
- **ACR Name**: `mytodoappacr`
- **Container Apps Environment**: `cae-todomanagement-dev`
- **PostgreSQL Server**: `pg-todomanagement-dev.postgres.database.azure.com`
- **PostgreSQL Database**: `tododb`
- **Managed Identity Name**: `uai-todomanagement-api`
- **Managed Identity Client ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Managed Identity Resource ID**: `/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-todomanagement-api`
- **Entra ID App Client ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Entra ID App Tenant ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Web Container App URL**: `https://app-todomanagement-web.<region>.azurecontainerapps.io`
- **API Container App URL**: `https://app-todomanagement-api.internal.<region>.azurecontainerapps.io`

---

## フェーズ 2: リポジトリを作成

> 所要時間の目安: 5-10 分

Azure インフラストラクチャの準備ができたので、GitHub リポジトリを作成します。

### ステップ 2.1: テンプレートからリポジトリを作成

参考: [テンプレートからリポジトリを作成する (GitHub Docs)](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)

1. テンプレートリポジトリを開きます
2. **Use this template** -> **Create a new repository** をクリックします
3. 以下を設定します:
   - **Repository name**: 例えば `my-todo-app`
   - **Visibility**: `Public` (このワークショップフローで推奨)
4. **Create repository from template** をクリックします
5. リポジトリが作成されるまで待ちます

---

## フェーズ 3: GitHub Actions を構成してデプロイ

> 所要時間の目安: 15-20 分

GitHub Actions を Azure 認証情報とリソース詳細で構成してから、ワークフローファイルを有効にして、空または失敗した初期実行を回避します。

### ステップ 3.1: Azure Service Principal と認証情報を作成

参考: [Azure Service Principal を作成する (MS Learn)](https://learn.microsoft.com/en-us/azure/developer/github/publish-docker-container)

1. Azure Portal で **Azure Cloud Shell** を開きます
2. Resource Group にスコープされた Service Principal を作成するために、このコマンドを実行します:

   ```powershell
   # 現在のサブスクリプションを確認します
   az account show

   # 異なるサブスクリプションに切り替えます (必要な場合)
   # `<subscription-id>` をフェーズ 1 サマリー (ステップ 1.9) からのサブスクリプション ID に置き換えます。
   az account set --subscription "<subscription-id>"

   # 変数を設定します
   $subscriptionId = $(az account show --query id -o tsv)
   $spName = "github-todomanagement-ci"
   # フェーズ 1 サマリー (ステップ 1.9) から Resource Group 名に置き換えます (変更した場合)。
   $resourceGroupName = "rg-todomanagement-dev"
   # Service Principal を作成します
   $sp = az ad sp create-for-rbac `
   --name $spName `
   --role "Owner" `
   --scopes "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" `
   --json-auth | ConvertFrom-Json

   # JSON として出力します (後で使用するために)
   $sp | ConvertTo-Json
   ```

3. JSON 出力 (全体 `{...}` ブロック) をコピーします

**注:** この JSON 出力は機密です。安全に保管してください。

---

### ステップ 3.2: GitHub Actions シークレットを追加

1. GitHub リポジトリで **Settings** に移動します
2. 左のメニューで **Secrets and variables** > **Actions** をクリックします
3. **New repository secret** をクリックします
4. **Name**: `AZURE_CREDENTIALS`
5. **Secret**: ステップ 3.1 からの JSON 出力を貼り付けます
6. **Add secret** をクリックします
   ![AZURE_CREDENTIALS シークレットを追加](image/DEPLOY_GUIDE_GUI/1776085536109.png)

---

### ステップ 3.3: GitHub Repository 変数を追加

参考: [GitHub Actions で変数を使用する (GitHub Docs)](https://docs.github.com/en/actions/learn-github-actions/variables)

GitHub リポジトリの **Settings** > **Secrets and variables** > **Actions** で、**Variables** をクリックして、これらのリポジトリ変数を追加します:

| 変数                             | 値                                     | 参照     |
| ------------------------------------ | ---------------------------------------- | ------------- |
| `RESOURCE_GROUP`                     | Resource Group 名                        | ステップ 1.9 から |
| `ACR_NAME`                           | ACR 名 (`.azurecr.io` なし)              | ステップ 1.9 から |
| `CONTAINER_APP_ENVIRONMENT`          | Container Apps Environment 名            | ステップ 1.9 から |
| `POSTGRES_SERVER`                    | PostgreSQL サーバー FQDN                 | ステップ 1.9 から |
| `POSTGRES_USER`                      | ユーザー割り当て管理対象アイデンティティ名 | ステップ 1.9 から |
| `POSTGRES_DB`                        | `tododb`                                 | 固定値   |
| `DATABASE_TYPE`                      | `postgresql`                             | 固定値   |
| `AZURE_CLIENT_ID`                    | Entra ID App Client ID                   | ステップ 1.9 から |
| `AZURE_TENANT_ID`                    | Entra ID App Tenant ID                   | ステップ 1.9 から |
| `USER_ASSIGNED_IDENTITY_CLIENT_ID`   | 管理対象アイデンティティ Client ID       | ステップ 1.9 から |
| `USER_ASSIGNED_IDENTITY_RESOURCE_ID` | 管理対象アイデンティティ Resource ID     | ステップ 1.9 から |
| `AZURE_REDIRECT_URI`                 | Web Container App URL                    | ステップ 1.9 から |
| `API_PROXY_TARGET`                   | 内部 API Container App URL               | ステップ 1.9 から |
| `REPOSITORY`                         | リポジトリ URL                           | ステップ 2.1 から |

---

### ステップ 3.4: ワークフローファイルを準備

参考: [GitHub Actions ドキュメント](https://docs.github.com/en/actions)

シークレットと変数が構成されたら、ワークフローファイルを有効にしてください。

リポジトリでは、CI/CD ワークフローファイルはテンプレートとして提供されています:

- `.github/workflows/build-deploy-api.yml.template` → `build-deploy-api.yml` に変更
- `.github/workflows/build-deploy-web.yml.template` → `build-deploy-web.yml` に変更

ファイルを作成するには:

1. Azure Portal で **Azure Cloud Shell** を開きます
2. このコマンドを実行します:

```powershell
git clone <your-repo-url>
cd my-todo-app

# テンプレートを .template 拡張子なしでコピーします
cp .github/workflows/build-deploy-api.yml.template .github/workflows/build-deploy-api.yml
cp .github/workflows/build-deploy-web.yml.template .github/workflows/build-deploy-web.yml

# コミットしてプッシュします
git add .github/workflows/*.yml
git commit -m "Enable API and Web build-deploy workflows"
git push origin main
```

---

### ステップ 3.5: GitHub Actions ワークフローを実行

1. リポジトリで **Actions** タブに移動します
2. 両方のワークフローが表示されるはずです:
   - `Build and Deploy API to ACR`
   - `Build and Deploy Web to ACR`
3. ワークフローが表示されない場合は、以下を確認してください:
   - `.github/workflows/build-deploy-api.yml` と `.github/workflows/build-deploy-web.yml` が `main` にコミットされている
4. ワークフローは `main` ブランチのコミットで自動的にトリガーされるはずです
5. 各ワークフローをクリックして監視します:
   - **赤色 X** (失敗) または **緑色チェック** (成功) がないか確認します
   - 両方とも 5-10 分以内に完了するはずです

**ワークフロー失敗のトラブルシューティング:**

- **AZURE_CREDENTIALS** が有効な JSON であることを確認します
- すべての変数が入力されていることを確認します
- Azure リソースが存在し、名前が正確に一致していることを確認します

---

## フェーズ 4: デプロイメントを検証

> 所要時間の目安: 10 分

### ステップ 4.1: Container App デプロイメントを確認

1. Azure Portal で **Container Apps Environment** に移動します
2. 2 つのコンテナーアプリが表示されるはずです:
   - `app-todomanagement-api`
   - `app-todomanagement-web`
3. `app-todomanagement-web` をクリックして、Web アプリの **URL** をメモします
4. `app-todomanagement-api` をクリックして、内部 API の **URL** をメモします

---

### ステップ 4.2: Entra ID リダイレクト URI を確認

リダイレクト URI は、ステップ 1.8 で登録した Web Container App URL と既に一致しているはずです。ここで確認し、必要な場合のみ更新してください。

1. **Entra ID App 登録** (ステップ 1.8 から) に移動します
2. **Authentication** をクリックします
3. SPA リダイレクト URI がステップ 4.1 からの Web Container App URL と一致していることを確認します
4. 追加または更新する必要がある場合は、`https://<your-web-url>` を使用します
   - `<your-web-url>` をステップ 4.1 からの Web アプリ URL に置き換えます
   - `/callback` を追加しないでください
5. **Access tokens** と **ID tokens** チェックボックスをチェックします
6. **Save** をクリックします

---

### ステップ 4.3: Web と API URL の GitHub 変数を確認

リポジトリの **Settings** > **Secrets and variables** > **Actions** に戻ります:

1. **Variables** をクリックします
2. `AZURE_REDIRECT_URI` を見つけて **Edit** をクリックします
   - 値が `https://<your-web-url>` であることを確認します
   - **Update variable** をクリックします
3. `API_PROXY_TARGET` を見つけて **Edit** をクリックします
   - 値がステップ 4.1 からの内部 API URL であることを確認します: `https://<your-api-url>`
   - **Update variable** をクリックします

これらの値が既にステップ 3.3 で設定した値と一致している場合、変更は不要です。

---

### ステップ 4.4: アプリケーションをテスト

1. Web アプリケーション URL をブラウザーで開きます
2. **Login** をクリックします
3. Microsoft Entra ID 認証情報でサインインします
4. ログインすると、**Todo List** ページが表示されるはずです
5. 機能をテストします:
   - **作成**: 新しい TODO アイテムを追加して保存をクリック
   - **編集**: TODO アイテムをクリックして編集
   - **削除**: 削除ボタンをクリックして TODO アイテムを削除
   - **更新**: ページを更新した後に、すべての変更が保持されているはずです

**ログインが失敗する場合:**

- Entra ID リダイレクト URI が正しいことを確認してください
- `AZURE_CLIENT_ID` と `AZURE_TENANT_ID` が正しいことを確認してください
- ブラウザーコンソールでエラー詳細を確認してください (F12 > Console)

**API が応答しない場合:**

- PostgreSQL データベースにアクセスできることを確認してください
- 管理対象アイデンティティがデータベースパーミッションを持っていることを確認してください
- Container Apps で API コンテナーのログを確認してください

---

## 完了のサマリー

Todo Management アプリケーションが Azure にデプロイされました。

**デプロイされたもの:**

- ✅ TODO スキーマ付き PostgreSQL データベース
- ✅ Azure Container Apps 内の API コンテナー
- ✅ Azure Container Apps 内の Web コンテナー
- ✅ Microsoft Entra ID 経由のユーザー認証
- ✅ GitHub Actions 経由の CI/CD パイプライン

**次のステップ:**

- Azure Application Insights でアプリケーションを監視
- `DEPLOY_GUIDE.md` で IaC アプローチを学習
- 組織に合わせてアプリケーションをカスタマイズ

---

## 一般的な問題とトラブルシューティング

### ワークフローが Azure にログインできない

**エラー**: `Error: Unable to login with service principal`

**ソリューション:**

- `AZURE_CREDENTIALS` シークレットに `az ad sp create-for-rbac --json-auth` からの有効な JSON が含まれていることを確認します
- JSON が切り詰められたり破損したりしていないことを確認します
- 必要に応じて Service Principal を再作成します: `az ad sp create-for-rbac --name "github-actions-todoapp" --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID> --json-auth`

### API が PostgreSQL に接続できない

**エラー**: `could not translate host name "pg-..." to address`

**ソリューション:**

- `POSTGRES_SERVER` 変数が PostgreSQL サーバーホスト名と正確に一致していることを確認します
- PostgreSQL サーバーが正しい VNet、サブネット、プライベート DNS ゾーンに接続されていることを確認します
- 管理対象アイデンティティが予想されるデータベースパーミッションを持っていることを確認します
- `POSTGRES_USER` が管理対象アイデンティティ名に設定されていることを確認します。`postgres` ではありません

### Web ログインが失敗するか、エラーが表示される

**エラー**: `AADSTS50058: Silent sign-in request failed`

**ソリューション:**

- `AZURE_CLIENT_ID` と `AZURE_TENANT_ID` が正しいことを確認します
- `AZURE_REDIRECT_URI` が Entra ID で登録された正確な URL と一致していることを確認します (ステップ 4.2)
- Entra ID のリダイレクト URI が `https://` スキームを持っていることを確認します
- Entra ID でアクセストークンと ID トークンが有効になっていることを確認します (ステップ 4.2)

### Container Apps にデプロイメントが表示されない

**エラー**: Container Apps Environment で `app-todomanagement-api` または `app-todomanagement-web` が表示されません

**ソリューション:**

- GitHub Actions ワークフローが正常に完了したことを確認します (赤色 X がない)
- ACR に新しいイメージがあることを確認します: Container Registry > Repositories に移動
- イメージがない場合、ワークフローが失敗した可能性があります - ワークフローログのエラーを確認します
- `ACR_NAME` と `RESOURCE_GROUP` が正確に一致していることを確認します (スペースなし)

---

## 次のステップ

- **ビギナーパス完了:** アプリケーションを使用する準備ができました!
- **上級パス:** `DEPLOY_GUIDE.md` で Infrastructure as Code を学習します

## Step 5. GitHub Actions の Secret と Variables を設定

リポジトリで以下を開きます。

- **Settings** -> **Secrets and variables** -> **Actions**

Secret:

- `AZURE_CREDENTIALS`: `az ad sp create-for-rbac --json-auth` で取得した JSON

Repository variables:

- `ACR_NAME`
- `RESOURCE_GROUP`
- `CONTAINER_APP_ENVIRONMENT`
- `POSTGRES_SERVER`
- `POSTGRES_DB` (既定: `tododb`)
- `POSTGRES_USER` (マネージド ID プリンシパル。`postgres` は不可)
- `DATABASE_TYPE` (`postgresql`)
- `AZURE_CLIENT_ID` (Microsoft Entra ID アプリの Client ID)
- `AZURE_TENANT_ID` (Microsoft Entra ID の Tenant ID)
- `AZURE_REDIRECT_URI` (Web アプリ URL)
- `API_PROXY_TARGET` (internal API URL)
- `USER_ASSIGNED_IDENTITY_CLIENT_ID`
- `USER_ASSIGNED_IDENTITY_RESOURCE_ID`

---

## Step 6. Push して GitHub Actions を実行

1. Workflow ファイルなどの変更をコミットします。
2. `main` に push します。
3. **Actions** タブで次の 2 つの workflow を確認します。
   - `Build and Deploy API to ACR`
   - `Build and Deploy Web to ACR`

---

## Step 7. デプロイ結果を確認

1. デプロイ後の Web URL を開きます。
2. **Login** を押して Microsoft Entra ID でサインインします。
3. Todo の作成、編集、削除を確認します。

---

## よくある問題

- Workflow が Azure にログインできない:
  - `AZURE_CREDENTIALS` の JSON 形式と権限範囲を確認
- API が PostgreSQL に接続できない:
  - `POSTGRES_SERVER`、ID 権限、ネットワーク設定を確認
- Web ログイン失敗:
  - `AZURE_CLIENT_ID`、`AZURE_TENANT_ID`、`AZURE_REDIRECT_URI` を確認

---

## 次のステップ

- 初学者コース: この GUI 手順を利用
- 上級コース: IaC 手順 `DEPLOY_GUIDE-ja_JP.md` へ

作成日: 2026-04-10
バージョン: 1.0
