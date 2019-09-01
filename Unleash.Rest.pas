unit Unleash.Rest;

interface

uses
  REST.Client,
  REST.Types,
  System.SysUtils,
  IPPeerClient;

type
  TRestConnection = class
  protected
    FRestResponse: TRESTResponse;
    FRestRequest: TRESTRequest;
    FRestClient: TRESTClient;
  public
    constructor Create(const BaseUrl: string);
    destructor Destroy; override;

    property Request: TRESTRequest
      read FRestRequest;
    property Client: TRESTClient
      read FRestClient;
    property Response: TRESTResponse
      read FRestResponse;
  end;

implementation

constructor TRestConnection.Create(const BaseUrl: string);
begin
  inherited Create;

  FRestResponse := TRESTResponse.Create(nil);
  FRestRequest := TRESTRequest.Create(nil);
  FRestClient := TRESTClient.Create(nil);

  FRestClient.BaseURL := BaseUrl;
  FRestClient.HandleRedirects := True;

  FRestRequest.Client := FRestClient;
  FRestRequest.Response := FRestResponse;
  FRestRequest.SynchronizedEvents := False;

  FRestRequest.Accept := 'application/json';
end;

destructor TRestConnection.Destroy;
begin
  FRestClient.Free;
  FRestRequest.Free;
  FRestResponse.Free;

  inherited;
end;

end.
