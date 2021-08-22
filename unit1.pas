unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  MaskEdit, IdHTTP, IdAntiFreeze, IdLogFile, fpjson, jsonparser,
  IdMultipartFormData;

type
  TMeuRetorno = record
  Lista : String;
  Retorno :String;
 end;

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    edtSenha: TEdit;
    edtUrl: TEdit;
    edtUsuario: TEdit;
    edtCnpj: TEdit;
    IdAntiFreeze1: TIdAntiFreeze;
    IdHTTP: TIdHTTP;
    IdLogFile1: TIdLogFile;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    mmTokem: TMemo;
    mmRetorno: TMemo;
    OpenDialog1: TOpenDialog;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    function ConectaApi : String;
    function EnvioXmlPost(tp_file:string): TMeuRetorno;
    function EnvioXmlCancelPut(tp_file:string): TMeuRetorno;
    function EnvioXmlCancelPost(tp_file:string): TMeuRetorno;
  public

  end;

var
  Form1: TForm1;
  AUrlAutentica, AUrlNfe, AUrlCancelNfe  : String;
  JsonUsuario, TokenAutoriza, PacthApp, PatchTemp : String;
  meuRetorno : TMeuRetorno;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
 AUrlAutentica := edtUrl.Text + '/api/v1/login';
 JsonUsuario   := '{"email": "' + edtUsuario.Text + '", "senha": "' + edtSenha.Text + '"}';
 IdLogFile1.LogTime := False;
 IdLogFile1.ReplaceCRLF := FAlse;
 IdLogFile1.Active := True;
 mmTokem.Lines.Clear;
 mmTokem.Lines.Add(ConectaApi);
 TokenAutoriza := mmTokem.Lines.Text;
 IdLogFile1.Active := False;
 mmRetorno.Lines.Clear;
 mmRetorno.Lines.Add(idHTTP.ResponseText);
end;

procedure TForm1.Button2Click(Sender: TObject);
Var
 arquivoXML : String;
begin
 OpenDialog1.Execute;
 arquivoXML := OpenDialog1.FileName;
 EnvioXmlPost(arquivoXML);
 mmRetorno.Lines.Add(arquivoXML + #13#10 +  #13#10 + meuRetorno.Retorno + #13#10 + #13#10 + meuRetorno.Lista);

end;

procedure TForm1.Button3Click(Sender: TObject);
Var
 arquivoXML : String;
begin
 OpenDialog1.Execute;
 arquivoXML := OpenDialog1.FileName;
 EnvioXmlCancelPost(arquivoXML);
 //EnvioXmlCancelPut(arquivoXML);
 mmRetorno.Lines.Add(arquivoXML + #13#10 +  #13#10 + meuRetorno.Retorno + #13#10 + #13#10 + meuRetorno.Lista);

end;

function TForm1.ConectaApi: String;
var
  code       : Integer;
  sResponse  : String;
  JsonToSend : TStringStream;
  JSonObject : TJsonObject;
  JSonData : TJsonData;
  sData: String;
  Response : string;
  LMsg     : string;
  Params   : TMemoryStream;
begin
  Params := TMemoryStream.Create;
  JsonToSend := TStringStream.Create(JsonUsuario , TEncoding.UTF8 );
  try
    try
      IdHTTP.Request.Clear;
      IdHTTP.Request.CustomHeaders.Clear;

      IdHTTP.ProtocolVersion := pv1_1;
      IdHTTP.Request.Accept := '';
      IdHTTP.Request.UserAgent := '';

      IdHTTP.Request.ContentType := 'application/json; charset=utf-8';

      sResponse := idHTTP.Post(AUrlAutentica, JsonToSend);
       //Lendo o Token de Acesso
      JSonData := GetJSON(sResponse);
      sData := JSonData.AsJSON;
      sData := JSonData.FormatJSON;
      JSonObject := TJSONObject(JSonData);
      sData := JSonObject.Get('token');

      result := sData;

    except
      on E: EIdHTTPProtocolException do
      begin
        result := 'Error on request: '#13#10 + e.Message + #13#10 + e.ErrorMessage;
        Exit;
      end;
    end;
  finally
    JsonToSend.Free();
  end;
end;

function TForm1.EnvioXmlPost(tp_file: string): TMeuRetorno;
Var
   Params : TIdMultipartFormDataStream;
   retorno,Lista: string;
begin

  Try
     Params := TIdMultipartFormDataStream.Create;
     Params.AddFile('arquivosXml', tp_file, 'application/xml');

     IdLogFile1.LogTime := False;
     IdLogFile1.ReplaceCRLF := FAlse;
     IdLogFile1.Active := True;

     IdHTTP.Request.CustomHeaders.Clear;
     IdHTTP.Request.Clear;

     IdHTTP.Request.Accept := '';
     IdHTTP.Request.UserAgent := '';
     IdHTTP.Request.CharSet := '';

     IdHTTP.Request.ContentType := 'application/xml';
     idHttp.Response.ResponseText := 'UTF-8';
     IdHTTP.Request.CustomHeaders.FoldLines := False;
     IdHTTP.Request.CustomHeaders.Add('Authorization:Bearer '+ TokenAutoriza);
     Try
      AUrlNfe := edtUrl.Text + '/api/v1/NFeArquivo/' + edtCnpj.Text + '/1';
      Lista   :=  IdHTTP.Post(AUrlNfe, Params );
      retorno := IdHTTP.ResponseText;
     except
        on E: EIdHTTPProtocolException do
        Begin
           IdHTTP.Disconnect;
           Case IdHTTP.ResponseCode of
          //Se o json conter algum erro
            400: begin
              retorno :=  '400: ' + e.ErrorMessage;
            end;
            //Se o token não for enviado ou for inválido
            401: begin
              retorno := '401: ' + e.ErrorMessage;
            end;
            //Se o token informado for inválido 403
            403: begin
              retorno := '403: ' + e.ErrorMessage;
            end;
            //Se não encontrar o que foi requisitado
            404:begin
              retorno := '404: ' + e.ErrorMessage;
            end;
            //Caso contrário
            else
              retorno := IdHTTP.ResponseText + ': ' + e.ErrorMessage;
          end;
        end;
     end;
  finally
     meuRetorno.Lista := Lista;
     meuRetorno.Retorno := retorno;
     Params.Free();
     IdLogFile1.Active := False;
  end;
end;

function TForm1.EnvioXmlCancelPut(tp_file: string): TMeuRetorno;
Var
   Params : TMemoryStream;
   retorno,Lista,S: string;

begin
    Try
     Params := TMemoryStream.Create;
     //Params.AddFile('arquivosXml', tp_file, 'multipart/form-data');

     IdLogFile1.LogTime := False;
     IdLogFile1.ReplaceCRLF := False;
     IdLogFile1.Active := True;

     IdHTTP.Request.CustomHeaders.Clear;
     IdHTTP.Request.Clear;

     IdHTTP.Request.Accept := '';
     IdHTTP.Request.UserAgent := '';
     IdHTTP.Request.CharSet := '';

     IdHTTP.Request.ContentType := 'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW';
     S := '----WebKitFormBoundary7MA4YWxkTrZu0gW' +
     CRLF + 'Content-Disposition: form-data; name="arquivosXml"; filename="'+tp_file+'"' +
     CRLF + 'Content-Type: ' ;
     Params.Write(S, Length(S));

     idHttp.Response.ResponseText := 'UTF-8';
     IdHTTP.Request.CustomHeaders.FoldLines := False;

     IdHTTP.Request.CustomHeaders.Add('Authorization:Bearer '+ TokenAutoriza);
     Try
      AUrlCancelNfe := edtUrl.Text + '/api/v1/CancelarDocumentoXml/55';
      Lista   :=  IdHTTP.Put(AUrlCancelNfe, Params);
      retorno := IdHTTP.ResponseText;
     except
        on E: EIdHTTPProtocolException do
        Begin
           IdHTTP.Disconnect;
           Case IdHTTP.ResponseCode of
          //Se o json conter algum erro
            400: begin
              retorno :=  '400: ' + e.ErrorMessage;
            end;
            //Se o token não for enviado ou for inválido
            401: begin
              retorno := '401: ' + e.ErrorMessage;
            end;
            //Se o token informado for inválido 403
            403: begin
              retorno := '403: ' + e.ErrorMessage;
            end;
            //Se não encontrar o que foi requisitado
            404:begin
              retorno := '404: ' + e.ErrorMessage;
            end;
            //Caso contrário
            else
              retorno := IdHTTP.ResponseText + ': ' + e.ErrorMessage;
          end;
        end;
     end;
  finally
     meuRetorno.Lista := Lista;
     meuRetorno.Retorno := retorno;
     Params.Free();
     IdLogFile1.Active := False;
  end;
end;

function TForm1.EnvioXmlCancelPost(tp_file: string): TMeuRetorno;
Var
   Params : TIdMultipartFormDataStream;
   retorno,Lista: string;
begin

  Try
     Params := TIdMultipartFormDataStream.Create;
     Params.AddFile('arquivosXml', tp_file, 'application/xml');

     IdLogFile1.LogTime := False;
     IdLogFile1.ReplaceCRLF := FAlse;
     IdLogFile1.Active := True;

     IdHTTP.Request.CustomHeaders.Clear;
     IdHTTP.Request.Clear;

     IdHTTP.Request.Accept := '';
     IdHTTP.Request.UserAgent := '';
     IdHTTP.Request.CharSet := '';

     IdHTTP.Request.ContentType := 'application/xml';
     idHttp.Response.ResponseText := 'UTF-8';
     IdHTTP.Request.CustomHeaders.FoldLines := False;
     IdHTTP.Request.CustomHeaders.Add('Authorization:Bearer '+ TokenAutoriza);
     Try
      AUrlNfe := edtUrl.Text + '/api/v1/CancelarDocumentoXml/55/';
      Lista   :=  IdHTTP.Post(AUrlNfe, Params );
      retorno := IdHTTP.ResponseText;
     except
        on E: EIdHTTPProtocolException do
        Begin
           IdHTTP.Disconnect;
           Case IdHTTP.ResponseCode of
          //Se o json conter algum erro
            400: begin
              retorno :=  '400: ' + e.ErrorMessage;
            end;
            //Se o token não for enviado ou for inválido
            401: begin
              retorno := '401: ' + e.ErrorMessage;
            end;
            //Se o token informado for inválido 403
            403: begin
              retorno := '403: ' + e.ErrorMessage;
            end;
            //Se não encontrar o que foi requisitado
            404:begin
              retorno := '404: ' + e.ErrorMessage;
            end;
            //Caso contrário
            else
              retorno := IdHTTP.ResponseText + ': ' + e.ErrorMessage;
          end;
        end;
     end;
  finally
     meuRetorno.Lista := Lista;
     meuRetorno.Retorno := retorno;
     Params.Free();
     IdLogFile1.Active := False;
  end;
end;

end.

