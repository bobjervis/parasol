
<h2>{@level 2 Installation}</h2>

<h3>{@level 3 License}</h3>

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

<h3>{@level 3 Download}</h3>
The Parasol language reference implementation may be installed from github by entering the following
command in a Linux shell terminal window:

{@code
    git clone git@github.com:bobjervis/parasol.git
}

<p>
This command will create a new directory named <span class=code>parasol</span> in the current working directory.
Consult the <span class=code>git</span> command help for options to customize your download point.

You may use the git repository you just cloned to run the compiler.
See the instructions under the {@doc-link tutorial tutorial.ph} section for more information.
<p>
You should add <span class=code><i>repository-path</i>/bin</span> to your <span class=code>PATH</span> variable 
in your <span class=code>.bashrc</span> file.
Otherwise, you will need to specify the path to the command you wish to run.

<h3>{@level 3 Installation}</h3>

If you prefer, you may install a binary installation of the compiler that is a subset of the git repository.
<p>
The installation script assumes you have a <span class=code>/usr/local/bin</span> directory on your machine. 
If not you will have to select another of the <span class=code>PATH</span> directories you have available and
modify the installation script to refer to that directory instead.
<p>
The script also assumes that <span class=code>/usr/parasol</span> is not being used on your computer for other purposes.
If you cannot install Parasol there, you will have ot edit the install script to place the public copy in a 
different place.
<p>
To install, run the following command:
<pre>{@code      <i>repository-path</i>/install.sh}</pre>
The script may prompt you for your root password to accomplish the install using <span class=code>sudo</span>, 
if you haven't entered the password recently.

