pageextension 50100 "Cust List" extends "Item List"
{

    actions
    {
        addafter(CopyItem)
        {
            action(SendData)
            {
                ApplicationArea = All;
                Promoted = true;

                trigger OnAction()
                begin
                    SendData();
                end;
            }
        }
    }

    local procedure SendData()
    var
        TypeHelper: Codeunit "Type Helper";
        HttpContent: HttpContent;
        HttpClient: HttpClient;
        HttpHeadersContent, HttpHeadersRequestMessage : HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        Parameters, ResponseText : Text;
        JsonToken: JsonToken;
        RequestURL: Text;
        AccessToken: Text;
        RequestBody: Text;
        Output: text;
        JObject: JsonObject;
        ItemTransSetup: Record "Item Transfer Setup";
        Company: Record "Company";
        AzureAdTenant: Codeunit "Azure AD Tenant";
    begin
        ItemTransSetup.Get();
        Company.Get(CompanyName);
        RequestURL := 'https://api.businesscentral.dynamics.com/v2.0/' + AzureAdTenant.GetAadTenantId() + '/' + ItemTransSetup."Environment Name" + '/ODataV4/ItemWS_ItemFromWS?company=' + DelChr(Company.Id, '<>', '{}');
        GenerateAccessToken(AccessToken);
        PrepareRequestBody(RequestBody);


        ItemFromWS(RequestBody);

        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(HttpHeadersContent);
        HttpHeadersContent.Remove('Content-Type');
        HttpHeadersContent.Add('Content-Type', 'application/json');
        HttpClient.SetBaseAddress(RequestURL);
        HttpClient.DefaultRequestHeaders.Add('User-Agent', 'Dynamics 365');
        HttpClient.DefaultRequestHeaders().Add('Authorization', 'Bearer ' + AccessToken);
        if HttpClient.Post(RequestURL, HttpContent, HttpResponseMessage) then
            HttpResponseMessage.Content.ReadAs(Output);
        Message(Output);
    end;

    local procedure GenerateAccessToken(var AccessToken: Text)
    var
        Scopes: List of [Text];
        ItemTransSetup: Record "Item Transfer Setup";
        AzureTenantId: Codeunit "Azure AD Tenant";
    begin
        ItemTransSetup.Get();
        ClientId := ItemTransSetup."Client ID";
        ClientSecret := ItemTransSetup."Client Secret";
        ResourceURL := 'https://api.businesscentral.dynamics.com/';

        AccessTokenURL := 'https://login.microsoftonline.com/' + AzureTenantId.GetAadTenantId() + '/oauth2/v2.0/token';
        Scopes.Add(ResourceURL + '.default');

        OAuth2.AcquireTokenWithClientCredentials(ClientId, ClientSecret, AccessTokenURL, RedirectURL, Scopes, AccessToken);

        if AccessToken = '' then
            Error('Unable to generate access token')
    end;

    local procedure PrepareRequestBody(var RequestBody: Text)
    var
        MainObject: JsonObject;
        ItemObject: JsonObject;
        InvPostingGrpObject: JsonObject;
        GenProdPostingGrpObject: JsonObject;
        InvPostingGrp: Record "Inventory Posting Group";
        GenProdPostingGrp: Record "Gen. Product Posting Group";
        JObject: JsonObject;
    begin
        ItemObject.Add('number', Rec."No.");
        ItemObject.Add('displayName', Rec.Description);
        ItemObject.Add('type', Format(Rec.Type));
        ItemObject.Add('itemCategoryCode', Rec."Item Category Code");
        ItemObject.Add('unitPrice', Rec."Unit Volume");
        ItemObject.Add('unitCost', Rec."Unit Cost");
        ItemObject.Add('taxGroupCode', Rec."Tax Group Code");
        ItemObject.Add('baseUnitOfMeasureCode', Rec."Base Unit of Measure");
        MainObject.Add('item', ItemObject);

        if InvPostingGrp.Get(Rec."Inventory Posting Group") then begin
            InvPostingGrpObject.Add('inventoryPostingGroupCode', Rec."Inventory Posting Group");
            InvPostingGrpObject.Add('inventoryPostingGroupDescription', InvPostingGrp.Description);
            MainObject.Add('inventoryPostingGroup', InvPostingGrpObject);
        end;

        if GenProdPostingGrp.Get(Rec."Gen. Prod. Posting Group") then begin
            GenProdPostingGrpObject.Add('generalProductPostingGroupCode', Rec."Gen. Prod. Posting Group");
            GenProdPostingGrpObject.Add('generalProductPostingGroupDescription', GenProdPostingGrp.Description);
            MainObject.Add('generalProductPostingGroup', GenProdPostingGrpObject);
        end;

        MainObject.WriteTo(RequestBody);
        JObject.Add('input', Base64Converter.ToBase64(RequestBody, TextEncoding::UTF8));
        JObject.WriteTo(RequestBody);
    end;

    procedure ItemFromWS(input: Text): Text
    var
        JObject: JsonObject;
        ItemJObject: JsonObject;
        JToken: JsonToken;
        Item: Record item;
        Base64String: Text;
        JSonText: Text;
    begin
        JObject.ReadFrom(input);
        if not GetJsonToken(JObject, 'value', JToken) then
            exit;

        exit(JToken.AsValue().AsText());
        Base64String := JToken.AsValue().AsText();
        JSonText := Base64Converter.FromBase64(Base64String);

        JObject.ReadFrom(JSonText);
        if JObject.Get('item', JToken) then begin
            ItemJObject := JToken.AsObject();
            Item.Init();
            if GetJsonToken(ItemJObject, 'number', JToken) then
                Item."No." := JToken.AsValue().AsText();
            Item.Description := 'Test karo bhai';
            Item.Insert(true);
        end;
    end;

    procedure GetJsonToken(JObject: JsonObject; FieldKey: Text; var JToken: JsonToken): Boolean
    begin
        if not JObject.Get(FieldKey, JToken) then
            exit(false);

        if JToken.AsValue().IsNull then
            exit(false);

        exit(true);
    end;

    var
        OAuth2: Codeunit Oauth2;
        Base64Converter: Codeunit "Base64 Convert";
        ClientId: Text;
        ClientSecret: Text;
        AccessTokenURL: Text;
        ResourceURL: Text;
        RedirectURL: Text;
}