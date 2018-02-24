using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;

namespace AzureAIDemo.Extensions.Action
{
    public abstract class VisionAction : DemoAction
    {
        protected abstract string ConstructHttpClient(HttpClient client);

        public override async Task<string> Act(string imageUri)
        {
            HttpClient client = new HttpClient();

            string uri = ConstructHttpClient(client);
            
            // Request body. Posts a locally stored JPEG image.
            byte[] byteData = GetImageAsByteArray(imageUri);

            using (ByteArrayContent content = new ByteArrayContent(byteData))
            {
                // This example uses content type "application/octet-stream".
                // The other content types you can use are "application/json" and "multipart/form-data".
                content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");

                // Execute the REST API call.
                HttpResponseMessage response = await client.PostAsync(uri, content);

                Log("Uploaded image to azure");

                // Get the JSON response.
                string contentString = await response.Content.ReadAsStringAsync();

                // Display the JSON response.
                StringBuilder sb = new StringBuilder();
                sb.Append("Response:\n");
                sb.Append(JsonPrettyPrint(contentString));
                return sb.ToString();
            }
        }
    }

    public class VisionAnalyzeAction : VisionAction
    {
        protected override string ConstructHttpClient(HttpClient client)
        {
            // Request headers.
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", Key);

            // Request parameters. A third optional parameter is "details".
            string requestParameters = "visualFeatures=Categories,Description,Color&language=en";

            // Assemble the URI for the REST API Call.
            return EndPoint + "/analyze?" + requestParameters;
        }
    }

    public class VisionTagAction : VisionAction
    {
        protected override string ConstructHttpClient(HttpClient client)
        {
            // Request headers.
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", Key);
            
            // Request parameters. A third optional parameter is "details".
            string requestParameters = "visualFeatures=Categories,Description,Color&language=en";

            // Assemble the URI for the REST API Call.
            return EndPoint + "/tag?" + requestParameters;
        }
    }

    public class VisionLandmarksAction : VisionAction
    {
        protected override string ConstructHttpClient(HttpClient client)
        {
            // Request headers.
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", Key);

            // Request parameters. A third optional parameter is "details".
            string requestParameters = "model=landmarks";

            // Assemble the URI for the REST API Call.
            return EndPoint + "/models/landmarks/analyze?" + requestParameters;
        }
    }

    public class VisionCelebritiesAction : VisionAction
    {
        protected override string ConstructHttpClient(HttpClient client)
        {
            // Request headers.
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", Key);

            // Request parameters. A third optional parameter is "details".
            string requestParameters = "model=celebrities";

            // Assemble the URI for the REST API Call.
            return EndPoint + "/models/celebrities/analyze?" + requestParameters;
        }
    }

    public class VisionOCRAction : VisionAction
    {
        protected override string ConstructHttpClient(HttpClient client)
        {
            // Request headers.
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", Key);

            // Request parameters. A third optional parameter is "details".
            string requestParameters = "detectOrientation=true";

            // Assemble the URI for the REST API Call.
            return EndPoint + "/ocr?" + requestParameters;
        }
    }

    public class FaceDetectAction : VisionAction
    {
        protected override string ConstructHttpClient(HttpClient client)
        {
            // Request headers.
            client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", Key);

            // Request parameters. A third optional parameter is "details".
            string requestParameters = "returnFaceId=true&returnFaceLandmarks=true&returnFaceAttributes=age,gender";

            // Assemble the URI for the REST API Call.
            return EndPoint + "/detect?" + requestParameters;
        }
    }
}
