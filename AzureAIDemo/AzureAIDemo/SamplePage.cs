using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

namespace AzureAIDemo
{
    public abstract class SamplePage : Page
    {
        protected MainWindow mainWindow = ((MainWindow)Application.Current.MainWindow);

        protected void Log(string str)
        {

            mainWindow.Log(str);
        }

        protected void ClearLog()
        {
            mainWindow.ClearLog();
        }
    }
}
