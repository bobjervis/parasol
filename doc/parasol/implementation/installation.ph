
<h2>{@level 0 INSTALLATION}</h2>

<h3>License</h2>

Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this product except in compliance with the License.
   You may obtain a copy of the License at

<pre>
       http://www.apache.org/licenses/LICENSE-2.0
</pre>
<p>

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

<h3>Download</h3>
The Parasol language reference implementation may be installed from github by entering the following
command in a Linux sheel terminal window:

{@code
    git clone git@github.com:bobjervis/parasol.git
}

<p>
This command will create a new directory named {@code parasol} in the current working directory. Consult the {@code git}
command help for options to customize your download point.

You may use the git repository you just cloned to run the compiler.
See the instructions under the {@link tutorial.ph} section for more information.
<p>
You should add {@code <i>repository-path</i>/bin} to your {@code PATH} variable in your {@code .bashrc} file.
Otheriwse, you will need to specify the path to the command you wish to run.

<h3>Installation</h3>

If you prefer, you may install a binary installation of the compiler that is a subset of the git repository.
<p>
The installation script assumes you have a {@code /usr/local/bin} directory on your machine. 
If not you will have to select another of the {@code PATH} directories you have available and modify the installation
script to refer to that directory instead.
<p>
The script also assume that {@code /usr/parasol} is not being used on your computer for other purposes.
If you cannot install Parasol there, you will have ot edit the install script to place the public copy in a 
different place.
<To install, run the following command:

<pre>
    {@code <i>repository-path</i>/install.sh}
</pre>

<p>
The script may prompt you for your root password to accomplish the install using {@code sudo}, if you 
haven't entered it recently.

